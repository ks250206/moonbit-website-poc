# LUMEN — MoonBit Maze Lab

**迷いながら、最短へ。** ランダムな迷路の中を、ダイクストラ法の探索が光の線となって広がるブラウザアプリです。探索が終わると、最短経路を金色の線がたどります。

**公開先:** https://ks250206.github.io/moonbit-website-poc/

GitHub Pages のデプロイ結果は [Test and deploy Lumen](https://github.com/ks250206/moonbit-website-poc/actions/workflows/ci.yml) で確認できます。

## MoonBit をどこまで使っているか

アプリケーションの計算・状態管理・UI構築・描画・アニメーションは MoonBit です。JavaScript でエンジンを再実装したものではありません。

| 部分 | 実装 | コンパイル先 |
|---|---|---|
| 乱数・迷路生成・優先度付きキュー・Dijkstra・経路復元 | `engine/engine.mbt` | 通常の WebAssembly |
| 操作・状態管理・描画座標・Canvas描画手順・アニメーション | `frontend/main.mbt` | JavaScript |
| UIマークアップ | `frontend/view.mbt` 内の文字列 | JavaScript |
| DOM / Canvas / WebAssembly / URL等の薄いアダプター | `frontend/browser.mbt` の `extern "js"` | JavaScript |
| 配色・レイアウト | `public/styles.css` | CSSのまま配信 |
| 起動用シェル | `public/index.html` | HTMLのまま配信 |

`extern "js"` の実装部分には実際に JavaScript が含まれます。「JavaScriptを一文字も書かない」構成ではありません。ただし、迷路生成や探索アルゴリズム、描画ループをJS側へ逃がしていません。Node/Pythonはテスト用途のみです。

`frontend` と `engine` は**別々にビルド**します。JSからWasmのエクスポートを明示的に呼び、MoonBitの構造体や配列をバックエンド間で直接共有しません。Wasm GC / SharedArrayBuffer / COOP・COEP は不要です。

## 操作と機能

- 穴掘り法（iterative DFS/backtracker）とランダムPrim法による迷路生成。同じシード・設定なら同じ迷路になります。
- ループの追加率を変更でき、複数の経路がある迷路も生成できます。0%は全域木の完全迷路です。
- 通行コストを有効にすると各セルが1〜9の重みを持ちます。重み切り替えで壁の配置は変わりません。
- 再生／一時停止、1ステップ、リセット、6段階の速度。スマートフォンでは迷路直下にも操作ボタンがあります。
- スタート／ゴールのクリック移動、シード変更、ランダム生成、設定入りURLの共有。
- 19×13〜95×63セル。エンジン単体は最大128×128まで扱えます。
- 青緑が確定済みの探索木、紫の点が候補、金色が最短経路。確定セル数・候補数・経路コスト・計算時間を表示します。
- Space: 再生／停止、→: 1ステップ、R: リセット、N: ランダム生成。入力操作中はショートカットを抑制します。

**最短経路コスト = 移動先セルのコストの総和**です。スタート自身のコストは含みません。重みなしでは最短歩数と一致しますが、重みありでは遠回りの方が低コストになる場合があります。ゴールを「発見した時」ではなく「最小距離が確定した時」に探索を終了します。

## ローカル実行

[公式手順](https://www.moonbitlang.com/download/)でMoonBitをインストールし、`moon`をPATHに追加してください。初期実装を検証したバージョンは以下です。

```text
moon 0.1.20261104 (940aa18 2026-11-04)
moonc v0.10.20+65efd5b93 (2026-11-05)
Node.js 22 / Python 3.11+ / Playwright 1.57.0
```

```sh
bash scripts/build.sh
python3 -m http.server 8000 --directory dist
```

ブラウザで `http://localhost:8000/` を開きます。`file://` からの直接起動ではWasmのfetchに失敗するため、HTTPサーバーを使用してください。

ビルドの内訳:

```sh
moon build engine --target wasm --release
moon build frontend --target js --release
```

npm install やフロントエンドのバンドラーは不要です。配布物は `dist/index.html`, `styles.css`, `app.js`, `engine.wasm`, `favicon.svg` です。Wasmは `document.baseURI` に対する相対URLから読み込むので、GitHub Pagesのリポジトリ配下でも動作します。読み込み失敗時はエラーを画面に表示します。

## テスト

```sh
moon fmt --check
bash scripts/build.sh
moon test engine --target wasm
node --test tests/engine.test.mjs
python3 -m pip install -r requirements-dev.txt
python3 -m playwright install chromium
python3 tests/browser_test.py
```

- **MoonBit白箱テスト5件:** PRNG既知値、到達不能、重み付き迂回、重複キュー、スタート=ゴール。
- **実Wasm統合テスト16件:** 84通りの設定・シードを含む生成グラフ検証、独立したO(V²)ソルバーとの最短距離照合、境界壁・壁対称性・連結性、経路コスト、再現性、不正引数、最大サイズ連続生成など。
- **ブラウザテスト9件:** 実HTTPで `/moonbit-website-poc/` を配信し、実Wasmを読み込んで操作、URL再現、エラー、モバイル、アクセシビリティ設定を確認します。`artifacts/` にスクリーンショットを出力します。

制限された検証環境向けに `LUMEN_OFFLINE_TEST=1` もあります。この場合だけfetch/historyをテスト用に置き換え、URL遷移テスト1件はスキップします。実際のコンパイル済みWasmは変えません。通常のCIではこのモードを使いません。

## GitHub Pages

`main`へのpushでビルド・テストを行い、成功した同一成果物をPagesにデプロイします。PRではテストと成果物保存のみです。

新しくforkした場合は、一度だけ **Settings → Pages → Build and deployment → Source: GitHub Actions** を選択してください。その後、Actionsの「Test and deploy Lumen」を手動実行するかmainへpushします。Pagesを有効にする管理権限は、通常のCI用GITHUB_TOKENとは別です。

CIは公式インストーラーの提供するMoonBitを使用し、実行ログへバージョンを記録します。コンパイラーのバージョンを固定した運用ではないため、将来の言語変更時には更新が必要な場合があります。

## 構成・実装上の判断

```text
engine/                  # Wasm: 生成・探索・復元
frontend/                # JS: MoonBitのUI・Canvas・FFI
public/                  # HTML/CSS/favicon
scripts/build.sh         # 両ターゲット → dist/
tests/engine.test.mjs     # 実Wasm + 独立ソルバー
tests/browser_test.py    # Playwright
.github/workflows/ci.yml  # 検証 → Pages
```

Dijkstraは二分最小ヒープと遅延削除を使います。一般にO((V+E) log V)、このグリッドではE=O(V)です。乱数はPark–Miller/Schrage方式で、符号付き32bit入力を正規化します。再帰は使わず、大きい迷路でもスタック深度に依存しません。

エンジンのWasm ABIは整数の関数だけです。

```text
generate(width, height, seed, loops, weighted, algorithm) -> cellCount / -1
reset(start, goal) -> 0 / -1
step(budget) -> status
wall(i), cost(i), parent(i), distance(i), mark(i)
visit_at(i), path_at(i)
visited_count(), frontier_count(), path_length(), status(), total_cost()
```

`status`: 0=準備、1=探索、2=到達、3=到達不能。`mark`: 0=未発見、1=候補、2=確定。壁bitは北=1/東=2/南=4/西=8。不正なgetter引数は-1、不正なgenerate/resetは既存状態を保持して-1を返します。

UIは壁とコストを生成時にキャッシュし、探索中は新規確定セルだけを取り込みます。各フレームの探索量を制限して描画へ制御を返します。Web Workerではなくメインスレッド上の時間分割であり、Wasm化だけで別スレッドになるわけではありません。「計算時間」は探索エンジン呼び出しの合計で、アニメーション待ち時間や描画時間を含みません。

### 参考

- [MoonBit FFI](https://docs.moonbitlang.com/en/latest/language/ffi.html)
- [Package configuration](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html)
- [Fullstack in one MoonBit project](https://docs.moonbitlang.com/en/latest/tutorial/fullstack-one-project.html)
