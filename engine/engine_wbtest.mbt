///|
test "Park-Miller known sequence is exact without overflow" {
  world.rng = 1
  assert_eq(random_below(2147483647), 16807)
  assert_eq(random_below(2147483647), 282475249)
  assert_eq(random_below(2147483647), 1622650073)
}

///|
test "unreachable target terminates without inventing a path" {
  assert_eq(generate(2, 2, 42, 0, 0, 0), 4)
  world.walls = Array::make(4, 15)
  assert_eq(reset(0, 3), 0)
  assert_eq(step(100), 3)
  assert_eq(visited_count(), 1)
  assert_eq(path_length(), 0)
  assert_eq(total_cost(), -1)
}

///|
test "weighted route can be longer in steps but cheaper" {
  assert_eq(generate(3, 2, 42, 100, 0, 0), 6)
  world.costs = [1, 9, 1, 1, 1, 1]
  assert_eq(reset(0, 2), 0)
  assert_eq(step(100), 2)
  assert_eq(total_cost(), 4)
  assert_eq(path_length(), 5)
  assert_eq(path_at(0), 0)
  assert_eq(path_at(4), 2)
}

///|
test "duplicate heap entries never settle the same cell twice" {
  ignore(generate(3, 3, 42, 100, 0, 0))
  heap_push(0, 0)
  assert_eq(step(1), 1)
  assert_eq(visited_count(), 1)
  assert_eq(step(1), 1)
  assert_eq(visited_count(), 2)
  assert_eq(visit_at(0), 0)
  assert_eq(visit_at(1), 1)
}

///|
test "start equals goal has zero cost and one path cell" {
  ignore(generate(3, 3, 5, 0, 1, 1))
  assert_eq(reset(4, 4), 0)
  assert_eq(step(1), 2)
  assert_eq(total_cost(), 0)
  assert_eq(path_length(), 1)
  assert_eq(path_at(0), 4)
}
