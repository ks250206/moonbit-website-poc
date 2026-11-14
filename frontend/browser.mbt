// This file is the complete handwritten JavaScript boundary. The functions
// below adapt browser primitives, not application logic or algorithms.

///|
#external
type Engine

///|
#external
type Canvas

///|
extern "js" fn mount(html : String) -> Unit =
  #|(html) => { document.getElementById('app').innerHTML = html; }

///|
extern "js" fn text(id : String, value : String) -> Unit =
  #|(id,value) => { document.getElementById(id).textContent = value; }

///|
extern "js" fn style(id : String, name : String, value : String) -> Unit =
  #|(id,name,value) => { document.getElementById(id).style.setProperty(name,value); }

///|
extern "js" fn attribute(id : String, name : String, value : String) -> Unit =
  #|(id,name,value) => { document.getElementById(id).setAttribute(name,value); }

///|
extern "js" fn set_value(id : String, value : String) -> Unit =
  #|(id,value) => { document.getElementById(id).value = value; }

///|
extern "js" fn value_int(id : String) -> Int32 =
  #|(id) => Number(document.getElementById(id).value) | 0

///|
extern "js" fn checked(id : String) -> Bool =
  #|(id) => document.getElementById(id).checked

///|
extern "js" fn set_checked(id : String, value : Bool) -> Unit =
  #|(id,value) => { document.getElementById(id).checked = value; }

///|
extern "js" fn disabled(id : String, value : Bool) -> Unit =
  #|(id,value) => { document.getElementById(id).disabled = value; }

///|
extern "js" fn on(id : String, event : String, callback : () -> Unit) -> Unit =
  #|(id,event,callback) => { document.getElementById(id).addEventListener(event,() => callback()); }

///|
extern "js" fn on_resize(callback : () -> Unit) -> Unit =
  #|(callback) => { new ResizeObserver(() => callback()).observe(document.getElementById('stage')); }

///|
extern "js" fn on_point(callback : (Double, Double) -> Unit) -> Unit =
  #|(callback) => { document.getElementById('overlay').addEventListener('pointerdown',e => { const r=e.currentTarget.getBoundingClientRect(); callback((e.clientX-r.left)/r.width,(e.clientY-r.top)/r.height); }); }

///|
extern "js" fn on_key(callback : (String) -> Unit) -> Unit =
  #|(callback) => { document.addEventListener('keydown',e => { if(e.ctrlKey||e.metaKey||e.altKey||e.repeat||/INPUT|SELECT|TEXTAREA|BUTTON|A/.test(e.target.tagName)) return; if([' ','ArrowRight','r','n'].includes(e.key)){e.preventDefault();callback(e.key);} }); }

///|
extern "js" fn frame(callback : (Double) -> Unit) -> Unit =
  #|(callback) => { requestAnimationFrame(callback); }

///|
extern "js" fn now() -> Double =
  #|() => performance.now()

///|
extern "js" fn reduced_motion() -> Bool =
  #|() => matchMedia('(prefers-reduced-motion: reduce)').matches

///|
extern "js" fn random_seed() -> Int32 =
  #|() => 1 + crypto.getRandomValues(new Uint32Array(1))[0] % 2147483645

///|
extern "js" fn query_int(name : String, fallback : Int32) -> Int32 =
  #|(name,fallback) => { const raw=new URLSearchParams(location.search).get(name); if(raw===null||raw.trim()==='')return fallback; const n=Number(raw); return Number.isSafeInteger(n)&&n>=-2147483648&&n<=2147483647?n:fallback; }

///|
extern "js" fn replace_query(query : String) -> Unit =
  #|(query) => { history.replaceState(null,'',location.pathname+query); }

///|
extern "js" fn copy_link(callback : (Bool) -> Unit) -> Unit =
  #|(callback) => { if(!navigator.clipboard){callback(false);return;} navigator.clipboard.writeText(location.href).then(()=>callback(true),()=>callback(false)); }

///|
extern "js" fn fixed(value : Double) -> String =
  #|(value) => value.toFixed(1)

///|
extern "js" fn load_engine(
  success : (Engine) -> Unit,
  failure : (String) -> Unit,
) -> Unit =
  #|(success,failure) => { (async()=>{ const response=await fetch(new URL('./engine.wasm',document.baseURI)); if(!response.ok)throw new Error('engine.wasm: HTTP '+response.status); const {instance}=await WebAssembly.instantiate(await response.arrayBuffer(),{}); success(instance.exports); })().catch(e=>failure(String(e))); }

///|
extern "js" fn generate_engine(
  e : Engine,
  w : Int32,
  h : Int32,
  seed : Int32,
  loops : Int32,
  weights : Int32,
  algorithm : Int32,
) -> Int32 =
  #|(e,w,h,seed,loops,weights,algorithm) => e.generate(w,h,seed,loops,weights,algorithm)

///|
extern "js" fn reset_engine(e : Engine, start : Int32, goal : Int32) -> Int32 =
  #|(e,start,goal) => e.reset(start,goal)

///|
extern "js" fn step_engine(e : Engine, count : Int32) -> Int32 =
  #|(e,count) => e.step(count)

///|
extern "js" fn engine_get(e : Engine, key : String, index : Int32) -> Int32 =
  #|(e,key,index) => e[key](index)

///|
extern "js" fn engine_stat(e : Engine, key : String) -> Int32 =
  #|(e,key) => e[key]()

///|
extern "js" fn context(id : String) -> Canvas =
  #|(id) => { const c=document.getElementById(id).getContext('2d'); if(!c)throw new Error('Canvas 2D unavailable'); return c; }

///|
extern "js" fn resize(c : Canvas, width : Double, height : Double) -> Unit =
  #|(c,w,h) => { const r=c.canvas.getBoundingClientRect(); const d=Math.min(devicePixelRatio||1,2); c.canvas.width=Math.max(1,Math.round(r.width*d)); c.canvas.height=Math.max(1,Math.round(r.height*d)); c.setTransform(c.canvas.width/w,0,0,c.canvas.height/h,0,0); c.lineCap='round'; c.lineJoin='round'; }

///|
extern "js" fn clear(c : Canvas, width : Double, height : Double) -> Unit =
  #|(c,w,h) => { c.clearRect(0,0,w,h); }

///|
extern "js" fn fill_color(c : Canvas, color : String) -> Unit =
  #|(c,color) => { c.fillStyle=color; }

///|
extern "js" fn stroke_color(c : Canvas, color : String, width : Double) -> Unit =
  #|(c,color,width) => { c.strokeStyle=color; c.lineWidth=width; }

///|
extern "js" fn rect(
  c : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit =
  #|(c,x,y,w,h) => { c.fillRect(x,y,w,h); }

///|
extern "js" fn begin(c : Canvas) -> Unit =
  #|(c) => { c.beginPath(); }

///|
extern "js" fn move_to(c : Canvas, x : Double, y : Double) -> Unit =
  #|(c,x,y) => { c.moveTo(x,y); }

///|
extern "js" fn line(c : Canvas, x : Double, y : Double) -> Unit =
  #|(c,x,y) => { c.lineTo(x,y); }

///|
extern "js" fn stroke(c : Canvas) -> Unit =
  #|(c) => { c.stroke(); }

///|
extern "js" fn circle(
  c : Canvas,
  x : Double,
  y : Double,
  radius : Double,
) -> Unit =
  #|(c,x,y,r) => { c.moveTo(x+r,y); c.arc(x,y,r,0,2*Math.PI); }

///|
extern "js" fn fill(c : Canvas) -> Unit =
  #|(c) => { c.fill(); }

///|
extern "js" fn alpha(c : Canvas, value : Double) -> Unit =
  #|(c,value) => { c.globalAlpha=value; }

///|
extern "js" fn label(
  c : Canvas,
  value : String,
  x : Double,
  y : Double,
  size : Double,
) -> Unit =
  #|(c,value,x,y,size) => { c.font=`600 ${size}px ui-monospace,monospace`; c.textAlign='center'; c.textBaseline='middle'; c.fillText(value,x,y); }
