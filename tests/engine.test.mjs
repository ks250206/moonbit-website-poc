/** Integration tests execute the actual MoonBit-compiled ordinary Wasm.
 * The deliberately simple O(V^2) reference solver is independent test code;
 * it is never included in the web application. */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const bytes = readFileSync(new URL('../dist/engine.wasm', import.meta.url));
const module = await WebAssembly.compile(bytes);
const make = async () => (await WebAssembly.instantiate(module, {})).exports;
function neighbors(i, w, h) {
  return [i >= w ? i-w : -1, i%w < w-1 ? i+1 : -1,
    i < w*(h-1) ? i+w : -1, i%w > 0 ? i-1 : -1];
}
function board(e,w,h) {
  return {w,h,walls:Array.from({length:w*h},(_,i)=>e.wall(i)),
    costs:Array.from({length:w*h},(_,i)=>e.cost(i))};
}
function topology(b, tree) {
  let edges=0;
  for(let i=0;i<b.w*b.h;i++) {
    for(const [d,j] of neighbors(i,b.w,b.h).entries()) {
      const closed=!!(b.walls[i]&(1<<d));
      if(j<0) assert.equal(closed,true,'outer boundary closed');
      else {
        assert.equal(closed,!!(b.walls[j]&(1<<((d+2)%4))),'wall symmetry');
        if(!closed) edges++;
      }
    }
  }
  const reached=new Set([0]),queue=[0];
  for(let k=0;k<queue.length;k++) for(const [d,j] of neighbors(queue[k],b.w,b.h).entries()) {
    if(j>=0&&!(b.walls[queue[k]]&(1<<d))&&!reached.has(j)) { reached.add(j);queue.push(j); }
  }
  assert.equal(reached.size,b.w*b.h,'connected');
  if(tree) assert.equal(edges/2,b.w*b.h-1,'perfect maze is a spanning tree');
}
function oracle(b,start,goal) {
  const n=b.w*b.h,dist=Array(n).fill(Infinity),used=Array(n).fill(false);dist[start]=0;
  for(let k=0;k<n;k++) {
    let u=-1;
    for(let i=0;i<n;i++) if(!used[i]&&(u<0||dist[i]<dist[u]))u=i;
    if(u<0||!Number.isFinite(dist[u]))return Infinity;
    if(u===goal)return dist[u];used[u]=true;
    for(const [d,v] of neighbors(u,b.w,b.h).entries())
      if(v>=0&&!(b.walls[u]&(1<<d)))dist[v]=Math.min(dist[v],dist[u]+b.costs[v]);
  }
  return dist[goal];
}
function validateSolution(e,b,start,goal) {
  assert.equal(e.status(),2);assert.equal(e.total_cost(),oracle(b,start,goal));
  const path=Array.from({length:e.path_length()},(_,i)=>e.path_at(i));
  assert.equal(path[0],start);assert.equal(path.at(-1),goal);
  assert.equal(new Set(path).size,path.length);
  let sum=0;
  for(let i=1;i<path.length;i++) {
    const d=neighbors(path[i-1],b.w,b.h).indexOf(path[i]);
    assert.ok(d>=0,'path uses adjacent cells');assert.equal(b.walls[path[i-1]]&(1<<d),0);
    sum+=b.costs[path[i]];
  }
  assert.equal(sum,e.total_cost());
  const seen=new Set();let previous=-1;
  for(let i=0;i<e.visited_count();i++) {
    const u=e.visit_at(i);assert.ok(!seen.has(u));seen.add(u);
    assert.ok(e.distance(u)>=previous,'nondecreasing settlement distances');previous=e.distance(u);
    if(u!==start)assert.ok(seen.has(e.parent(u)),'parent settled earlier');
  }
  assert.equal(e.visit_at(e.visited_count()-1),goal,'goal is settled before termination');
}

test('ordinary Wasm has no host imports',()=>assert.deepEqual(WebAssembly.Module.imports(module),[]));
for(const algorithm of [0,1]) for(const weighted of [0,1]) for(const loops of [0,35,100]) {
  test(`generator ${algorithm}, weighted ${weighted}, loops ${loops}: graph properties + oracle`,async()=>{
    const e=await make();
    for(const seed of [1,42,20261114,-1,0,2147483647,-2147483648]) {
      assert.equal(e.generate(11,9,seed,loops,weighted,algorithm),99);
      const b=board(e,11,9);topology(b,loops===0);
      assert.ok(b.costs.every(c=>c>=1&&c<=9));
      if(!weighted)assert.ok(b.costs.every(c=>c===1));
      assert.equal(e.reset(7,91),0);
      for(let k=0;k<100&&e.status()<2;k++) {
        const count=e.visited_count();e.step(1);
        assert.ok(e.visited_count()-count<=1,'budget counts unique settled cells');
      }
      validateSolution(e,b,7,91);
      const path=Array.from({length:e.path_length()},(_,i)=>e.path_at(i));
      e.generate(11,9,seed,loops,weighted,algorithm);
      assert.deepEqual(board(e,11,9),b,'seed replay');
      e.reset(7,91);e.step(10000);
      assert.deepEqual(Array.from({length:e.path_length()},(_,i)=>e.path_at(i)),path,'step batching does not change route');
    }
  });
}
test('weights do not alter the topology and weighted grid is not just BFS',async()=>{
  const e=await make();let foundDifferent=false;
  for(let seed=1;seed<=20;seed++) {
    e.generate(9,7,seed,60,0,1);const walls=board(e,9,7).walls;e.step(1000);const shortestSteps=e.path_length()-1;
    e.generate(9,7,seed,60,1,1);assert.deepEqual(board(e,9,7).walls,walls);e.step(1000);
    if(e.path_length()-1>shortestSteps)foundDifferent=true;
  }
  assert.equal(foundDifferent,true,'at least one cheapest path takes more steps');
});
test('reset, bad inputs, safe getters and zero budgets',async()=>{
  const e=await make();assert.equal(e.reset(0,0),-1);assert.equal(e.step(1),0);
  e.generate(5,4,42,0,0,0);const b=board(e,5,4);
  for(const args of [[1,4,1,0,0,0],[129,2,1,0,0,0],[2,2,1,-1,0,0],[2,2,1,101,0,0],[2,2,1,0,0,2]]) {
    assert.equal(e.generate(...args),-1);assert.deepEqual(board(e,5,4),b);
  }
  assert.equal(e.reset(-1,1),-1);assert.equal(e.reset(0,20),-1);
  e.step(0);e.step(-100);assert.equal(e.visited_count(),0);
  e.step(3);assert.equal(e.visited_count(),3);
  e.reset(4,4);assert.equal(e.visited_count(),0);e.step(1);
  assert.equal(e.total_cost(),0);assert.equal(e.path_length(),1);assert.equal(e.path_at(0),4);
  for(const getter of ['wall','cost','parent','distance','mark','visit_at','path_at']) {
    assert.equal(e[getter](-1),-1);assert.equal(e[getter](1_000_000),-1);
  }
  e.generate(4,3,99,0,0,1);assert.equal(e.status(),0);assert.equal(e.total_cost(),-1);assert.equal(e.path_length(),0);
});
test('largest supported engine grid and repeated regeneration remain bounded',async()=>{
  const e=await make();
  for(let run=0;run<12;run++) {
    assert.equal(e.generate(128,128,run+1,65,1,run%2),16384);
    assert.equal(e.step(2147483647),2);
    assert.ok(e.path_length()>1&&e.path_length()<=16384);
    assert.ok(e.visited_count()<=16384);
    assert.ok(e.total_cost()>0);
  }
});
