// All maze generation and pathfinding live here. The exported ABI uses only
// i32 values, never MoonBit's private array/object memory representation.

///|
priv struct World {
  mut width : Int32
  mut height : Int32
  mut rng : Int32
  mut walls : Array[Int32]
  mut costs : Array[Int32]
  mut distances : Array[Int32]
  mut parents : Array[Int32]
  mut marks : Array[Int32]
  mut heap_nodes : Array[Int32]
  mut heap_costs : Array[Int32]
  mut heap_size : Int32
  mut order : Array[Int32]
  mut order_size : Int32
  mut path : Array[Int32]
  mut path_size : Int32
  mut frontier : Int32
  mut status : Int32
  mut start : Int32
  mut goal : Int32
}

///|
let world : World = {
  width: 0,
  height: 0,
  rng: 1,
  walls: [],
  costs: [],
  distances: [],
  parents: [],
  marks: [],
  heap_nodes: [],
  heap_costs: [],
  heap_size: 0,
  order: [],
  order_size: 0,
  path: [],
  path_size: 0,
  frontier: 0,
  status: 0,
  start: 0,
  goal: 0,
}

// Park–Miller with Schrage's method: no overflowing intermediate Int arithmetic.

///|
fn random_below(bound : Int32) -> Int32 {
  let hi = world.rng / 127773
  let lo = world.rng % 127773
  let next = 16807 * lo - 2836 * hi
  world.rng = if next <= 0 { next + 2147483647 } else { next }
  world.rng % bound
}

///|
fn bit(direction : Int32) -> Int32 {
  match direction {
    0 => 1
    1 => 2
    2 => 4
    _ => 8
  }
}

///|
fn has_wall(cell : Int32, direction : Int32) -> Bool {
  world.walls[cell] / bit(direction) % 2 == 1
}

///|
fn neighbor(cell : Int32, direction : Int32) -> Int32 {
  let x = cell % world.width
  let y = cell / world.width
  match direction {
    0 => if y > 0 { cell - world.width } else { -1 }
    1 => if x + 1 < world.width { cell + 1 } else { -1 }
    2 => if y + 1 < world.height { cell + world.width } else { -1 }
    _ => if x > 0 { cell - 1 } else { -1 }
  }
}

///|
fn carve(cell : Int32, direction : Int32) -> Unit {
  let other = neighbor(cell, direction)
  if other >= 0 && has_wall(cell, direction) {
    world.walls[cell] = world.walls[cell] - bit(direction)
    let reverse = (direction + 2) % 4
    world.walls[other] = world.walls[other] - bit(reverse)
  }
}

///|
fn generate_backtracker(count : Int32) -> Unit {
  let seen = Array::make(count, false)
  let stack = Array::make(count, 0)
  let choices = Array::make(4, 0)
  let first = random_below(count)
  stack[0] = first
  seen[first] = true
  let mut size = 1
  while size > 0 {
    let cell = stack[size - 1]
    let mut available = 0
    for d = 0; d < 4; d = d + 1 {
      let other = neighbor(cell, d)
      if other >= 0 && !seen[other] {
        choices[available] = d
        available = available + 1
      }
    }
    if available == 0 {
      size = size - 1
    } else {
      let d = choices[random_below(available)]
      let other = neighbor(cell, d)
      carve(cell, d)
      seen[other] = true
      stack[size] = other
      size = size + 1
    }
  }
}

///|
fn generate_prim(count : Int32) -> Unit {
  let seen = Array::make(count, false)
  let edges = Array::make(count * 4, 0)
  let mut size = 0
  let first = random_below(count)
  seen[first] = true
  for d = 0; d < 4; d = d + 1 {
    if neighbor(first, d) >= 0 {
      edges[size] = first * 4 + d
      size = size + 1
    }
  }
  while size > 0 {
    let at = random_below(size)
    let edge = edges[at]
    size = size - 1
    edges[at] = edges[size]
    let cell = edge / 4
    let d = edge % 4
    let other = neighbor(cell, d)
    if !seen[other] {
      seen[other] = true
      carve(cell, d)
      for next = 0; next < 4; next = next + 1 {
        let n = neighbor(other, next)
        if n >= 0 && !seen[n] {
          edges[size] = other * 4 + next
          size = size + 1
        }
      }
    }
  }
}

///|
fn before(
  cost_a : Int32,
  node_a : Int32,
  cost_b : Int32,
  node_b : Int32,
) -> Bool {
  cost_a < cost_b || (cost_a == cost_b && node_a < node_b)
}

///|
fn heap_push(node : Int32, cost : Int32) -> Unit {
  let mut at = world.heap_size
  world.heap_size = world.heap_size + 1
  while at > 0 {
    let parent = (at - 1) / 2
    if !before(cost, node, world.heap_costs[parent], world.heap_nodes[parent]) {
      break
    }
    world.heap_nodes[at] = world.heap_nodes[parent]
    world.heap_costs[at] = world.heap_costs[parent]
    at = parent
  }
  world.heap_nodes[at] = node
  world.heap_costs[at] = cost
}

///|
fn heap_remove_min() -> Unit {
  world.heap_size = world.heap_size - 1
  if world.heap_size == 0 {
    return
  }
  let node = world.heap_nodes[world.heap_size]
  let cost = world.heap_costs[world.heap_size]
  let mut at = 0
  while at * 2 + 1 < world.heap_size {
    let mut child = at * 2 + 1
    if child + 1 < world.heap_size &&
      before(
        world.heap_costs[child + 1],
        world.heap_nodes[child + 1],
        world.heap_costs[child],
        world.heap_nodes[child],
      ) {
      child = child + 1
    }
    if !before(world.heap_costs[child], world.heap_nodes[child], cost, node) {
      break
    }
    world.heap_nodes[at] = world.heap_nodes[child]
    world.heap_costs[at] = world.heap_costs[child]
    at = child
  }
  world.heap_nodes[at] = node
  world.heap_costs[at] = cost
}

///|
#export_name("reset")
pub fn reset(start : Int32, goal : Int32) -> Int32 {
  let count = world.width * world.height
  if count == 0 || start < 0 || goal < 0 || start >= count || goal >= count {
    return -1
  }
  world.start = start
  world.goal = goal
  world.distances = Array::make(count, 1073741823)
  world.parents = Array::make(count, -1)
  world.marks = Array::make(count, 0)
  // Each directed edge can relax at most once after its source is settled.
  world.heap_nodes = Array::make(count * 4 + 1, 0)
  world.heap_costs = Array::make(count * 4 + 1, 0)
  world.heap_size = 0
  world.order = Array::make(count, 0)
  world.order_size = 0
  world.path = Array::make(count, 0)
  world.path_size = 0
  world.frontier = 1
  world.status = 0
  world.distances[start] = 0
  world.marks[start] = 1
  heap_push(start, 0)
  0
}

///|
#export_name("generate")
pub fn generate(
  width : Int32,
  height : Int32,
  seed : Int32,
  loops : Int32,
  weighted : Int32,
  algorithm : Int32,
) -> Int32 {
  // Validate before allocation; bad callers leave the current maze untouched.
  if width < 2 ||
    height < 2 ||
    width > 128 ||
    height > 128 ||
    loops < 0 ||
    loops > 100 ||
    algorithm < 0 ||
    algorithm > 1 {
    return -1
  }
  world.width = width
  world.height = height
  let initial = seed % 2147483646
  world.rng = if initial <= 0 { initial + 2147483646 } else { initial }
  let count = width * height
  world.walls = Array::make(count, 15)
  world.costs = Array::make(count, 1)
  if algorithm == 0 {
    generate_backtracker(count)
  } else {
    generate_prim(count)
  }
  // Add alternate routes without ever disconnecting the spanning tree.
  for cell = 0; cell < count; cell = cell + 1 {
    for d = 1; d <= 2; d = d + 1 {
      if neighbor(cell, d) >= 0 &&
        has_wall(cell, d) &&
        random_below(100) < loops {
        carve(cell, d)
      }
    }
  }
  // Generate costs after topology, so toggling weights preserves the maze.
  if weighted != 0 {
    for cell = 0; cell < count; cell = cell + 1 {
      world.costs[cell] = 1 + random_below(9)
    }
  }
  ignore(reset(0, count - 1))
  count
}

///|
fn reconstruct() -> Unit {
  let mut cell = world.goal
  let mut size = 0
  while cell >= 0 && size < world.width * world.height {
    world.path[size] = cell
    size = size + 1
    if cell == world.start {
      break
    }
    cell = world.parents[cell]
  }
  world.path_size = size
  for i = 0; i < size / 2; i = i + 1 {
    let opposite = size - i - 1
    let tmp = world.path[i]
    world.path[i] = world.path[opposite]
    world.path[opposite] = tmp
  }
}

///|
#export_name("step")
pub fn step(budget : Int32) -> Int32 {
  if world.width == 0 || budget <= 0 || world.status >= 2 {
    return world.status
  }
  world.status = 1
  let limit = if budget > 16384 { 16384 } else { budget }
  let mut settled = 0
  while settled < limit && world.heap_size > 0 {
    let cell = world.heap_nodes[0]
    let distance = world.heap_costs[0]
    heap_remove_min()
    // Lazy decrease-key: stale heap entries are not settlement events.
    if world.marks[cell] != 2 && distance == world.distances[cell] {
      world.marks[cell] = 2
      world.frontier = world.frontier - 1
      world.order[world.order_size] = cell
      world.order_size = world.order_size + 1
      settled = settled + 1
      // Stop when the target is settled, not when it is merely discovered.
      if cell == world.goal {
        world.status = 2
        reconstruct()
        return 2
      }
      for d = 0; d < 4; d = d + 1 {
        let other = neighbor(cell, d)
        if other >= 0 && !has_wall(cell, d) && world.marks[other] != 2 {
          let candidate = distance + world.costs[other]
          if candidate < world.distances[other] {
            world.distances[other] = candidate
            world.parents[other] = cell
            if world.marks[other] == 0 {
              world.marks[other] = 1
              world.frontier = world.frontier + 1
            }
            heap_push(other, candidate)
          }
        }
      }
    }
  }
  if world.heap_size == 0 {
    world.status = 3
  }
  world.status
}

///|
fn safe_at(values : Array[Int32], index : Int32, length : Int32) -> Int32 {
  if index >= 0 && index < length {
    values[index]
  } else {
    -1
  }
}

///|
#export_name("wall")
pub fn wall(index : Int32) -> Int32 {
  safe_at(world.walls, index, world.walls.length())
}

///|
#export_name("cost")
pub fn cost(index : Int32) -> Int32 {
  safe_at(world.costs, index, world.costs.length())
}

///|
#export_name("parent")
pub fn parent(index : Int32) -> Int32 {
  safe_at(world.parents, index, world.parents.length())
}

///|
#export_name("distance")
pub fn distance(index : Int32) -> Int32 {
  safe_at(world.distances, index, world.distances.length())
}

///|
#export_name("mark")
pub fn mark(index : Int32) -> Int32 {
  safe_at(world.marks, index, world.marks.length())
}

///|
#export_name("visit_at")
pub fn visit_at(index : Int32) -> Int32 {
  safe_at(world.order, index, world.order_size)
}

///|
#export_name("path_at")
pub fn path_at(index : Int32) -> Int32 {
  safe_at(world.path, index, world.path_size)
}

///|
#export_name("visited_count")
pub fn visited_count() -> Int32 {
  world.order_size
}

///|
#export_name("frontier_count")
pub fn frontier_count() -> Int32 {
  world.frontier
}

///|
#export_name("path_length")
pub fn path_length() -> Int32 {
  world.path_size
}

///|
#export_name("status")
pub fn status() -> Int32 {
  world.status
}

///|
#export_name("total_cost")
pub fn total_cost() -> Int32 {
  if world.status == 2 {
    world.distances[world.goal]
  } else {
    -1
  }
}
