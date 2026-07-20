# Wall Rally

Flame と Forge2D を使った、一人用の2次元壁打ちテーブルテニスゲームです。縦方向のコートで重力を受けるボールをラケットで打ち上げ、できるだけ長くラリーを続けます。

## 遊び方

- `A` / `D` または左右矢印キー: ラケットを移動
- マウス移動: ポインターへラケットを移動
- タッチドラッグ: ラケットを移動
- `Space`: ラケットを振る（打球時はスマッシュボーナス）
- `Enter` またはタップ: サーブ
- `R` またはタップ: ゲームオーバー後にリスタート

ボールは打ち上げると重力で減速し、頂点を迎えたあと自由落下します。連続リターン数に応じて得点が増え、5回ごとに初速が上昇します。タイミングよくラケットを振って返すとスマッシュになり、50点のボーナスと打球速度が加算されます。ボールを3回落とすとゲームオーバーです。

コート上部のオレンジ色のターゲットにボールを当てると爆発し、近くのターゲットへ誘爆します。連鎖数が大きいほどボーナスが増え、爆風はボールの軌道も変化させます。爆発で生じた破片は重力を受け、壁やほかのオブジェクトと衝突します。青いバンパーはボールを強く反射し、ヒットごとに25点を獲得できます。すべてのターゲットを破壊すると次のウェーブが始まります。

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
