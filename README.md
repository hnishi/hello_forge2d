# Wall Rally

Flame と Forge2D を使った、一人用の2次元壁打ちテーブルテニスゲームです。横長のコートで重力を受けるボールを右側の壁へ打ち返し、できるだけ長くラリーを続けます。プレイヤーの操作エリアはコート左半分です。

## 遊び方

- `W` / `A` / `S` / `D` または矢印キー: 操作エリア内でラケットを上下左右に移動
- マウス移動: 操作エリア内でポインターへラケットを移動
- タッチドラッグ: 操作エリア内でラケットを上下左右に移動
- `Space`: ラケットを振る（打球時はスマッシュボーナス）
- `Enter` またはタップ: サーブ
- `R` またはタップ: ゲームオーバー後にリスタート

ボールは打ち上げると重力で減速し、頂点を迎えたあと自由落下します。連続リターン数に応じて得点が増え、5回ごとに初速が上昇します。タイミングよくラケットを振って返すとスマッシュになり、50点のボーナスと打球速度が加算されます。ボールを3回落とすとゲームオーバーです。

ボールには摩擦と回転があり、ラケットの横移動とスイング方向からスピンが加わります。回転中は赤い表面模様が動き、マグヌス効果で軌道が曲がります。水色の矢印が速度、黄色の矢印が加速度を表し、HUDには速度・角速度・運動エネルギーと各ベクトルの数値を表示します。

アリーナには物性の異なるゴム、鉄、氷、木、ゼリー、磁石があります。ゴムは高反発・高摩擦、鉄は重く低反発、氷は低摩擦、木は中程度の反発、ゼリーは衝突を強く減衰させ、磁石は距離に応じてボールを引き寄せます。

コート上部のオレンジ色のターゲットにボールを当てると短い導火時間を経て爆発し、近くのターゲットへ誘爆します。爆風は距離の二乗に応じて弱まり、壁や材質オブジェクトの裏では遮蔽されます。圧力波は広がる円で表示され、質量の異なる破片は重力を受けながら互いに衝突し、ターゲットへの二次衝突でも爆発を起こします。軽い物体ほど爆風で大きく速度が変化します。青いバンパーはボールを強く反射し、ヒットごとに25点を獲得できます。すべてのターゲットを破壊すると次のウェーブが始まります。

## 実行

```sh
flutter pub get
flutter run -d chrome
```

ゲームルールのテストは `flutter test` で実行できます。

## GitHub Pagesへのデプロイ

本番環境はGitHub Pagesでホストされます。デプロイは [`.github/workflows/release_deploy_web.yml`](.github/workflows/release_deploy_web.yml) に定義されたGitHub Actionsによって行われます。

デプロイの流れは次のとおりです。

1. 変更を `main` ブランチへpushします。
2. `Deploy to web (GitHub Pages)` ワークフローが起動します。必要に応じてActions画面から手動実行することもできます。
3. `ubuntu-latest` 上にFlutter 3.44.6 stableをセットアップし、`flutter pub get` を実行します。
4. リポジトリ配下で配信できるよう、base hrefを `/hello_forge2d/` に設定してFlutter Webのリリースビルドを作成します。
5. `peaceiris/actions-gh-pages` が `build/web` の内容を `gh-pages` ブランチへpublishします。
6. GitHub Pagesが `gh-pages` ブランチのルートを公開します。

公開URLは次のとおりです。

```text
https://hnishi.github.io/hello_forge2d/
```

`GITHUB_TOKEN` はActionsが自動発行するため、通常は個別のデプロイ用トークンを登録する必要はありません。リポジトリでは次の設定が必要です。

- **Settings → Pages → Build and deployment**: `Deploy from a branch`
- **Branch**: `gh-pages` / `/ (root)`
- **Settings → Actions → General → Workflow permissions**: Actionsから `gh-pages` へ書き込める権限

デプロイ前の解析は [`.github/workflows/analyze.yml`](.github/workflows/analyze.yml) が担当し、Pull Requestおよび `main` へのpush時に実行されます。ローカルでは次のコマンドでPages向けのビルドを確認できます。

```sh
flutter analyze
flutter test
flutter build web --release --base-href "/hello_forge2d/"
```

デプロイに失敗した場合は、GitHubの **Actions** タブから対象ワークフローのログを確認します。復旧後は失敗したrunを再実行するか、修正コミットを `main` へpushします。以前のバージョンへ戻す場合は対象変更をrevertして `main` へpushすると、同じ仕組みで再デプロイされます。
