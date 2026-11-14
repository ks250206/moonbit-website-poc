// The UI markup is emitted by the MoonBit JS frontend; no JS UI framework.

///|
fn view() -> String {
  let html =
    #|<header class="topbar">
    #|  <a class="brand" href="./" aria-label="Lumen Maze Lab ホーム"><span class="brand-mark">L</span><span>LUMEN<span class="brand-sub">MAZE LAB</span></span></a>
    #|  <div class="top-right"><span class="runtime"><i></i> MOONBIT × WEBASSEMBLY</span><a class="source" href="https://github.com/ks250206/moonbit-website-poc" target="_blank" rel="noopener noreferrer">Source <span aria-hidden="true">↗</span></a></div>
    #|</header>
    #|<main>
    #|  <section class="intro"><div><p class="eyebrow">ALGORITHM PLAYGROUND / 001</p><h1>迷いながら、<span>最短へ。</span></h1><p class="intro-copy">小さな探索が、ひとつの道になる。迷路をつくって、ダイクストラ法の思考を眺めよう。</p></div><span class="intro-note">GENERATE. EXPLORE. DISCOVER.</span></section>
    #|  <div class="workspace">
    #|    <aside class="sidebar">
    #|      <section class="control-section"><div class="section-head"><h2><span>01</span> 迷路をつくる</h2><span class="small-label">GENERATOR</span></div>
    #|        <label class="field" for="size">グリッドサイズ<select id="size"><option value="19">19 × 13 · Small</option><option value="31" selected>31 × 21 · Medium</option><option value="47">47 × 31 · Large</option><option value="71">71 × 47 · Extra large</option><option value="95">95 × 63 · Stress test</option></select></label>
    #|        <label class="field" for="algorithm">生成アルゴリズム<select id="algorithm"><option value="0">穴掘り法 · Backtracker</option><option value="1">ランダム Prim 法</option></select></label>
    #|        <label class="field" for="seed">シード値 <span class="label-note">同じ値で再現</span><div class="input-row"><input id="seed" type="number" min="1" max="2147483646" value="20261114" inputmode="numeric" spellcheck="false"><button id="shuffle" class="icon-button" aria-label="ランダムシードで新しい迷路を生成" title="ランダムに生成 (N)">⤨</button></div></label>
    #|        <div class="field"><label for="loops">ループの追加率 <output id="loops-value" for="loops">15%</output></label><input id="loops" type="range" min="0" max="70" step="5" value="15"><div class="range-labels"><span>一本道</span><span>選択肢を増やす</span></div></div>
    #|        <label class="toggle-row" for="weighted"><span><strong>通行コストをつける</strong><small>各セルのコストを 1〜9 に</small></span><input id="weighted" type="checkbox" role="switch"><span class="toggle-track" aria-hidden="true"></span></label>
    #|        <button id="generate" class="secondary-button full" disabled>この設定で生成 <span aria-hidden="true">↻</span></button>
    #|      </section>
    #|      <section class="control-section"><div class="section-head"><h2><span>02</span> 探索を眺める</h2><span class="small-label">DIJKSTRA</span></div>
    #|        <div class="field"><label for="speed">探索スピード <output id="speed-value" for="speed">120 / 秒</output></label><input id="speed" type="range" min="0" max="5" step="1" value="2"><div class="range-labels"><span>じっくり</span><span>一気に</span></div></div>
    #|        <button id="play" class="primary-button full" disabled><span id="play-icon" aria-hidden="true">▶</span> <span id="play-text">探索をはじめる</span><kbd>Space</kbd></button>
    #|        <div class="button-pair"><button id="step" class="secondary-button" disabled>1 ステップ <span aria-hidden="true">→</span></button><button id="reset" class="secondary-button" disabled>リセット <span aria-hidden="true">↺</span></button></div>
    #|        <label class="field endpoint-field" for="endpoint">迷路をクリックして<select id="endpoint"><option value="0">位置の変更なし</option><option value="1">スタートを移動</option><option value="2">ゴールを移動</option></select></label>
    #|      </section>
    #|      <div class="engine-note"><span class="engine-icon">W</span><div><strong>計算は、MoonBit → Wasm。</strong><p>描画と操作も MoonBit → JS。<br>サーバーなしで、ブラウザの中で。</p></div></div>
    #|    </aside>
    #|    <div class="main-column">
    #|      <section class="visualizer" aria-label="迷路と探索の可視化">
    #|        <div class="canvas-toolbar"><div class="canvas-title"><span class="live-dot" id="live-dot"></span><span id="status" role="status" aria-live="polite">Wasm エンジンを読み込み中…</span></div><div class="canvas-actions"><span id="grid-label">31 × 21</span><button id="share" class="text-button" title="現在の迷路のURLをコピー">共有 <span aria-hidden="true">↗</span></button></div></div>
    #|        <div class="stage-wrap"><div id="stage" class="stage"><canvas id="maze" aria-hidden="true"></canvas><canvas id="overlay" role="img" aria-label="迷路。青緑の線が確定済みの探索木、紫の点が探索候補、金の線が最短経路です。" aria-describedby="canvas-description"></canvas></div><div id="loading" class="loading">INITIALIZING WASM<span class="loading-line"></span></div></div>
    #|        <div class="mobile-transport"><button id="mobile-play" class="primary-button" disabled><span id="mobile-play-text">▶ 探索をはじめる</span></button><button id="mobile-step" class="secondary-button" aria-label="1 ステップ進む" disabled>→</button><button id="mobile-reset" class="secondary-button" aria-label="探索をリセット" disabled>↺</button></div>
    #|        <div class="canvas-footer"><div class="legend"><span><i class="swatch start"></i>スタート</span><span><i class="swatch goal"></i>ゴール</span><span><i class="swatch visited"></i>探索済み</span><span><i class="swatch frontier"></i>候補</span><span><i class="swatch path"></i>最短経路</span></div><span id="seed-label" class="seed-badge">SEED 20261114</span></div>
    #|        <div class="progress-track"><div id="progress"></div></div>
    #|      </section>
    #|      <section class="metrics" aria-label="探索の統計"><div class="metric"><span>確定したセル <small>SETTLED</small></span><strong id="visited">0 <em>/ 651</em></strong></div><div class="metric"><span>探索候補 <small>FRONTIER</small></span><strong id="frontier">1</strong></div><div class="metric"><span>最短経路コスト <small>COST</small></span><strong id="cost">—</strong></div><div class="metric"><span>エンジン実行時間 <small>COMPUTE</small></span><strong><span id="compute">0.0</span><em> ms</em></strong></div></section>
    #|      <section class="explanation"><div class="explanation-copy"><p class="eyebrow">WHAT YOU'RE WATCHING</p><h2>近いところから、確実に。</h2><p id="canvas-description">スタートからの累積コストが最小のセルを、ひとつずつ確定。青緑の枝は探索木、金色の線はゴールまでの最短経路です。</p><p id="path-info" class="path-info">すべての通行コストが 1 のとき、最短経路は最小の歩数になります。</p></div><div class="algorithm-card"><div class="code-heading"><span>DIJKSTRA</span><span>O((V + E) log V)</span></div><code><span id="code-0"><b>01</b> スタートを優先度付きキューへ</span><span id="code-1"><b>02</b> 累積コストが最小のセルを確定</span><span id="code-2"><b>03</b> 隣接セルのコストを更新</span><span id="code-3"><b>04</b> ゴール確定 → 親をたどって復元</span></code></div></section>
    #|      <p id="notice" class="notice" role="status" aria-live="polite"></p>
    #|    </div>
    #|  </div>
    #|  <footer class="footer"><span>LUMEN / A MOONBIT EXPERIMENT</span><span>Seeded randomness. Deterministic paths.</span><span>UI → JS <i>+</i> ENGINE → WASM</span></footer>
    #|</main>
  html
}
