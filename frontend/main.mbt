///|
priv struct App {
  engine : Engine
  base : Canvas
  overlay : Canvas
  reduced : Bool
  mut width : Int32
  mut height : Int32
  mut seed : Int32
  mut loops : Int32
  mut weighted : Int32
  mut algorithm : Int32
  mut start : Int32
  mut goal : Int32
  mut walls : Array[Int32]
  mut costs : Array[Int32]
  mut marks : Array[Int32]
  mut parents : Array[Int32]
  mut order : Array[Int32]
  mut born : Array[Double]
  mut path : Array[Int32]
  mut collected : Int32
  mut phase : Int32
  mut running : Bool
  mut speed : Double
  mut credit : Double
  mut route : Double
  mut compute : Double
  mut last : Double
  mut changed : Double
  mut dirty : Bool
}

///|
fn clamp(value : Int32, low : Int32, high : Int32) -> Int32 {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
fn minimum(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn maximum(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn cell_x(a : App, cell : Int32) -> Double {
  (cell % a.width).to_double() + 1.5
}

///|
fn cell_y(a : App, cell : Int32) -> Double {
  (cell / a.width).to_double() + 1.5
}

///|
fn valid_width(w : Int32) -> Int32 {
  match w {
    19 | 31 | 47 | 71 | 95 => w
    _ => 31
  }
}

///|
fn maze_height(w : Int32) -> Int32 {
  match w {
    19 => 13
    31 => 21
    47 => 31
    71 => 47
    _ => 63
  }
}

///|
fn update_url(a : App) -> Unit {
  replace_query(
    "?seed=\{a.seed}&size=\{a.width}&algorithm=\{a.algorithm}&loops=\{a.loops}&weighted=\{a.weighted}&start=\{a.start}&goal=\{a.goal}",
  )
}

///|
fn draw_base(a : App) -> Unit {
  let c = a.base
  clear(c, (a.width + 2).to_double(), (a.height + 2).to_double())
  for i = 0; i < a.walls.length(); i = i + 1 {
    let x = (i % a.width).to_double() + 1.0
    let y = (i / a.width).to_double() + 1.0
    if a.weighted == 1 {
      fill_color(c, "#f6c878")
      alpha(c, a.costs[i].to_double() * 0.017)
      rect(c, x + 0.07, y + 0.07, 0.86, 0.86)
      if a.width <= 31 && a.costs[i] > 1 {
        alpha(c, 0.37)
        label(c, "\{a.costs[i]}", x + 0.5, y + 0.51, 0.30)
      }
    }
  }
  alpha(c, 1.0)
  stroke_color(c, "#354653", 0.055)
  begin(c)
  for i = 0; i < a.walls.length(); i = i + 1 {
    let x = (i % a.width).to_double() + 1.0
    let y = (i / a.width).to_double() + 1.0
    let mask = a.walls[i]
    if mask % 2 == 1 {
      move_to(c, x, y)
      line(c, x + 1.0, y)
    }
    if mask / 8 % 2 == 1 {
      move_to(c, x, y)
      line(c, x, y + 1.0)
    }
    if i % a.width == a.width - 1 {
      move_to(c, x + 1.0, y)
      line(c, x + 1.0, y + 1.0)
    }
    if i / a.width == a.height - 1 {
      move_to(c, x, y + 1.0)
      line(c, x + 1.0, y + 1.0)
    }
  }
  stroke(c)
}

///|
fn fit(a : App) -> Unit {
  resize(a.base, (a.width + 2).to_double(), (a.height + 2).to_double())
  resize(a.overlay, (a.width + 2).to_double(), (a.height + 2).to_double())
  draw_base(a)
  a.dirty = true
}

///|
fn marker(a : App, cell : Int32, color : String, letter : String) -> Unit {
  let c = a.overlay
  let x = cell_x(a, cell)
  let y = cell_y(a, cell)
  fill_color(c, color)
  alpha(c, 0.12)
  begin(c)
  circle(c, x, y, 0.53)
  fill(c)
  alpha(c, 1.0)
  begin(c)
  circle(c, x, y, 0.30)
  fill(c)
  fill_color(c, "#0d1a19")
  label(c, letter, x, y + 0.015, 0.29)
}

///|
fn draw_search(a : App, time : Double) -> Unit {
  let c = a.overlay
  clear(c, (a.width + 2).to_double(), (a.height + 2).to_double())
  let duration = if a.reduced {
    0.001
  } else {
    minimum(150.0, maximum(45.0, 12000.0 / a.speed))
  }
  // Two batched strokes make a soft glow without a per-edge shadow/filter.
  for pass = 0; pass < 2; pass = pass + 1 {
    alpha(c, if pass == 0 { 0.12 } else { 0.86 })
    stroke_color(c, "#59d6c3", if pass == 0 { 0.30 } else { 0.09 })
    begin(c)
    for k = 0; k < a.collected; k = k + 1 {
      let cell = a.order[k]
      let parent = a.parents[cell]
      if parent >= 0 {
        let progress = minimum(
          1.0,
          maximum(0.0, (time - a.born[cell]) / duration),
        )
        let ease = progress * (2.0 - progress)
        let x = cell_x(a, parent)
        let y = cell_y(a, parent)
        move_to(c, x, y)
        line(
          c,
          x + (cell_x(a, cell) - x) * ease,
          y + (cell_y(a, cell) - y) * ease,
        )
      }
    }
    stroke(c)
  }
  alpha(c, 0.9)
  fill_color(c, "#b4a6ff")
  begin(c)
  for i = 0; i < a.marks.length(); i = i + 1 {
    if a.marks[i] == 1 {
      circle(c, cell_x(a, i), cell_y(a, i), 0.085)
    }
  }
  fill(c)
  if a.phase == 2 && a.path.length() > 1 {
    for pass = 0; pass < 2; pass = pass + 1 {
      alpha(c, if pass == 0 { 0.16 } else { 1.0 })
      stroke_color(c, "#f6c878", if pass == 0 { 0.40 } else { 0.16 })
      begin(c)
      move_to(c, cell_x(a, a.path[0]), cell_y(a, a.path[0]))
      for i = 1; i < a.path.length(); i = i + 1 {
        let p = minimum(1.0, maximum(0.0, a.route - (i - 1).to_double()))
        if p > 0.0 {
          let previous = a.path[i - 1]
          let cell = a.path[i]
          line(
            c,
            cell_x(a, previous) + (cell_x(a, cell) - cell_x(a, previous)) * p,
            cell_y(a, previous) + (cell_y(a, cell) - cell_y(a, previous)) * p,
          )
        }
      }
      stroke(c)
    }
  }
  alpha(c, 1.0)
  if a.start == a.goal {
    marker(a, a.start, "#f6c878", "◎")
  } else {
    marker(a, a.start, "#a7f3ce", "S")
    marker(a, a.goal, "#ff9b83", "G")
  }
}

///|
fn update_stats(a : App) -> Unit {
  text("visited", "\{a.collected} / \{a.width * a.height}")
  text("frontier", "\{engine_stat(a.engine, "frontier_count")}")
  text("compute", fixed(a.compute))
  let cost = engine_stat(a.engine, "total_cost")
  text("cost", if cost >= 0 { "\{cost}" } else { "—" })
  style(
    "progress",
    "width",
    "\{a.collected.to_double() * 100.0 / (a.width * a.height).to_double()}%",
  )
  let complete = a.phase == 2 && a.route >= (a.path.length() - 1).to_double()
  let status = if complete {
    "最短経路が見つかりました"
  } else if a.phase == 2 {
    if a.running {
      "最短経路を描画中"
    } else {
      "経路の描画を一時停止"
    }
  } else if a.phase == 3 {
    "ゴールに到達できません"
  } else if a.running {
    "探索中 — 近いセルから順に確定"
  } else if a.collected > 0 {
    "一時停止中"
  } else {
    "準備完了 — 探索をはじめよう"
  }
  text("status", status)
  text(
    "play-text",
    if a.running {
      "一時停止"
    } else if complete {
      "もう一度みる"
    } else if a.collected > 0 {
      "探索を再開"
    } else {
      "探索をはじめる"
    },
  )
  text("play-icon", if a.running { "Ⅱ" } else { "▶" })
  attribute("play", "aria-pressed", if a.running { "true" } else { "false" })
  disabled("step", a.running || complete)
  disabled("mobile-step", a.running || complete)
  text(
    "mobile-play-text",
    if a.running {
      "Ⅱ 一時停止"
    } else if complete {
      "▶ もう一度みる"
    } else if a.collected > 0 {
      "▶ 再開"
    } else {
      "▶ 探索をはじめる"
    },
  )
  attribute(
    "mobile-play",
    "aria-pressed",
    if a.running {
      "true"
    } else {
      "false"
    },
  )
  style(
    "live-dot",
    "background",
    if a.phase == 2 {
      "#f6c878"
    } else if a.running {
      "#a7f3ce"
    } else {
      "#7b8c9f"
    },
  )
  for i = 0; i < 4; i = i + 1 {
    let active = if a.phase == 2 {
      i == 3
    } else if a.collected > 0 {
      i == 1 || i == 2
    } else {
      i == 0
    }
    attribute("code-\{i}", "data-active", if active { "true" } else { "false" })
  }
  attribute("app", "data-phase", "\{a.phase}")
  attribute("app", "data-running", if a.running { "true" } else { "false" })
  if a.phase == 2 {
    text(
      "path-info",
      "最短経路は \{a.path.length() - 1} 歩、累積コスト \{cost}。スタート自身のコストは含みません。",
    )
  }
}

///|
fn reset_search(a : App) -> Unit {
  ignore(reset_engine(a.engine, a.start, a.goal))
  let count = a.width * a.height
  a.marks = Array::make(count, 0)
  a.marks[a.start] = 1
  a.parents = Array::make(count, -1)
  a.order = Array::make(count, 0)
  a.born = Array::make(count, 0.0)
  a.path = []
  a.collected = 0
  a.phase = 0
  a.running = false
  a.credit = 0.0
  a.route = 0.0
  a.compute = 0.0
  a.changed = now()
  a.dirty = true
  text(
    "path-info",
    if a.weighted == 1 {
      "明るいセルほど通行コストが高い設定。歩数が少ない道と、コストが最小の道は同じとは限りません。"
    } else {
      "すべての通行コストが 1 のとき、最短経路は最小の歩数になります。"
    },
  )
  update_stats(a)
}

///|
fn generate(a : App, restore : Bool) -> Unit {
  a.width = valid_width(value_int("size"))
  a.height = maze_height(a.width)
  a.seed = clamp(value_int("seed"), 1, 2147483646)
  a.loops = clamp(value_int("loops"), 0, 70)
  a.weighted = if checked("weighted") { 1 } else { 0 }
  a.algorithm = clamp(value_int("algorithm"), 0, 1)
  let count = generate_engine(
    a.engine,
    a.width,
    a.height,
    a.seed,
    a.loops,
    a.weighted,
    a.algorithm,
  )
  if count < 0 {
    text(
      "notice", "迷路を生成できませんでした。設定を確認してください。",
    )
    return
  }
  a.start = if restore { clamp(query_int("start", 0), 0, count - 1) } else { 0 }
  a.goal = if restore {
    clamp(query_int("goal", count - 1), 0, count - 1)
  } else {
    count - 1
  }
  a.walls = Array::make(count, 0)
  a.costs = Array::make(count, 1)
  for i = 0; i < count; i = i + 1 {
    a.walls[i] = engine_get(a.engine, "wall", i)
    a.costs[i] = engine_get(a.engine, "cost", i)
  }
  set_value("seed", "\{a.seed}")
  text("grid-label", "\{a.width} × \{a.height}")
  text("seed-label", "SEED \{a.seed}")
  style("stage", "aspect-ratio", "\{a.width + 2} / \{a.height + 2}")
  text("notice", "")
  update_url(a)
  reset_search(a)
  fit(a)
}

///|
fn advance(a : App, count : Int32, time : Double) -> Unit {
  let before = now()
  a.phase = step_engine(a.engine, count)
  a.compute = a.compute + now() - before
  let end = engine_stat(a.engine, "visited_count")
  for k = a.collected; k < end; k = k + 1 {
    let cell = engine_get(a.engine, "visit_at", k)
    a.order[k] = cell
    a.parents[cell] = engine_get(a.engine, "parent", cell)
    a.marks[cell] = 2
    a.born[cell] = time
    // Cache only changed cells. These reads carry engine state, not a JS solver.
    let candidates = [cell - a.width, cell + 1, cell + a.width, cell - 1]
    for j = 0; j < 4; j = j + 1 {
      let n = candidates[j]
      if n >= 0 && n < a.marks.length() {
        a.marks[n] = engine_get(a.engine, "mark", n)
      }
    }
  }
  a.collected = end
  if a.phase == 2 {
    let length = engine_stat(a.engine, "path_length")
    a.path = Array::make(length, 0)
    for i = 0; i < length; i = i + 1 {
      a.path[i] = engine_get(a.engine, "path_at", i)
    }
    if a.reduced {
      a.route = (length - 1).to_double()
    }
  }
  if a.phase == 3 {
    a.running = false
  }
  a.changed = time
  a.dirty = true
}

///|
fn tick(a : App, time : Double) -> Unit {
  let dt = if a.last == 0.0 {
    0.0
  } else {
    minimum(50.0, maximum(0.0, time - a.last))
  }
  a.last = time
  if a.running {
    if a.phase < 2 {
      a.credit = a.credit + dt * a.speed / 1000.0
      let budget = clamp(a.credit.to_int(), 0, 512)
      if budget > 0 {
        a.credit = a.credit - budget.to_double()
        advance(a, budget, time)
      }
    } else if a.phase == 2 {
      a.route = minimum(
        (a.path.length() - 1).to_double(),
        a.route + dt * maximum(20.0, a.speed * 0.7) / 1000.0,
      )
      a.changed = time
      a.dirty = true
      if a.route >= (a.path.length() - 1).to_double() {
        a.running = false
      }
    }
  }
  if a.dirty || time - a.changed < 180.0 {
    draw_search(a, time)
    update_stats(a)
    a.dirty = false
  }
  frame(t => tick(a, t))
}

///|
fn play(a : App) -> Unit {
  if a.phase == 2 && a.route >= (a.path.length() - 1).to_double() {
    reset_search(a)
  }
  a.running = !a.running
  a.last = now()
  a.dirty = true
  update_stats(a)
}

///|
fn single_step(a : App) -> Unit {
  if a.running {
    return
  }
  if a.phase < 2 {
    advance(a, 1, now())
  } else if a.phase == 2 {
    a.route = minimum((a.path.length() - 1).to_double(), a.route + 1.0)
    a.dirty = true
  }
  update_stats(a)
}

///|
fn shuffle(a : App) -> Unit {
  set_value("seed", "\{random_seed()}")
  generate(a, false)
}

///|
fn speed_changed(a : App) -> Unit {
  let speeds = [12, 40, 120, 360, 1200, 5000]
  let speed = speeds[clamp(value_int("speed"), 0, 5)]
  a.speed = speed.to_double()
  text("speed-value", "\{speed} / 秒")
}

///|
fn start(engine : Engine) -> Unit {
  let a : App = {
    engine,
    base: context("maze"),
    overlay: context("overlay"),
    reduced: reduced_motion(),
    width: 31,
    height: 21,
    seed: 20261114,
    loops: 15,
    weighted: 0,
    algorithm: 0,
    start: 0,
    goal: 650,
    walls: [],
    costs: [],
    marks: [],
    parents: [],
    order: [],
    born: [],
    path: [],
    collected: 0,
    phase: 0,
    running: false,
    speed: 120.0,
    credit: 0.0,
    route: 0.0,
    compute: 0.0,
    last: 0.0,
    changed: 0.0,
    dirty: true,
  }
  set_value("size", "\{valid_width(query_int("size", 31))}")
  set_value("seed", "\{clamp(query_int("seed", 20261114), 1, 2147483646)}")
  set_value("algorithm", "\{clamp(query_int("algorithm", 0), 0, 1)}")
  set_value("loops", "\{clamp(query_int("loops", 15), 0, 70)}")
  set_checked("weighted", query_int("weighted", 0) == 1)
  text("loops-value", "\{value_int("loops")}%")
  generate(a, true)
  style("loading", "display", "none")
  for
    id in [
      "generate", "play", "step", "reset", "mobile-play", "mobile-step", "mobile-reset",
    ] {
    disabled(id, false)
  }
  on("generate", "click", () => generate(a, false))
  on("shuffle", "click", () => shuffle(a))
  on("play", "click", () => play(a))
  on("mobile-play", "click", () => play(a))
  on("mobile-step", "click", () => single_step(a))
  on("mobile-reset", "click", () => reset_search(a))
  on("step", "click", () => single_step(a))
  on("reset", "click", () => reset_search(a))
  on("speed", "input", () => speed_changed(a))
  on("loops", "input", () => text("loops-value", "\{value_int("loops")}%"))
  for id in ["size", "algorithm", "weighted", "seed", "loops"] {
    on(id, "change", () => {
      text(
        "notice", "設定変更は「この設定で生成」で反映されます。",
      )
    })
  }
  on("share", "click", () => {
    copy_link(ok => {
      text(
        "notice",
        if ok {
          "この迷路のURLをコピーしました。"
        } else {
          "コピーできませんでした。アドレスバーのURLを共有してください。"
        },
      )
    })
  })
  on("endpoint", "change", () => {
    style(
      "overlay",
      "cursor",
      if value_int("endpoint") == 0 {
        "default"
      } else {
        "crosshair"
      },
    )
    text(
      "notice",
      if value_int("endpoint") == 0 {
        ""
      } else {
        "迷路のセルをクリックして位置を指定してください。"
      },
    )
  })
  on_point((px, py) => {
    let mode = value_int("endpoint")
    let x = px * (a.width + 2).to_double() - 1.0
    let y = py * (a.height + 2).to_double() - 1.0
    if mode > 0 &&
      x >= 0.0 &&
      y >= 0.0 &&
      x < a.width.to_double() &&
      y < a.height.to_double() {
      let cell = y.to_int() * a.width + x.to_int()
      if mode == 1 {
        a.start = cell
      } else {
        a.goal = cell
      }
      reset_search(a)
      update_url(a)
    }
  })
  on_key(key => {
    match key {
      " " => play(a)
      "ArrowRight" => single_step(a)
      "r" => reset_search(a)
      "n" => shuffle(a)
      _ => ()
    }
  })
  on_resize(() => fit(a))
  attribute("app", "data-ready", "true")
  frame(t => tick(a, t))
}

///|
fn main {
  mount(view())
  load_engine(start, message => {
    text(
      "loading", "Wasm の読み込みに失敗しました。ページを再読み込みしてください。",
    )
    text("status", "エンジンを読み込めませんでした")
    text("notice", message)
    attribute("app", "data-ready", "error")
  })
}
