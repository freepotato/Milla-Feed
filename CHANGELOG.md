# Changelog

## [0.1.3](https://github.com/freepotato/Milla-Feed/compare/v0.1.2...v0.1.3) (2026-10-30)


### Reverts

* **ci:** restore the automatic release-please flow ([be85978](https://github.com/freepotato/Milla-Feed/commit/be859786effed28eff6e96250fa744da7869d295))

## [0.1.2](https://github.com/freepotato/Milla-Feed/compare/v0.1.1...v0.1.2) (2026-10-30)


### Features

* **feed:** show the latest 30 items and archive the rest by date ([5bb2424](https://github.com/freepotato/Milla-Feed/commit/5bb24240fd21374506e140acee5b77a474928421))
* **news:** fetch the remoshuang ranked list in site order with a rising section ([48cfd3d](https://github.com/freepotato/Milla-Feed/commit/48cfd3d9249f60287c22fee49d07547e15cd3cbb))


### Bug Fixes

* **home:** hide the system scroll indicator ([171b529](https://github.com/freepotato/Milla-Feed/commit/171b5290a70ddd0f01f7f9e1f425b31a4b3c51b4))
* **news:** keep ranked row ids unique and drop the refresh animation ([832ff76](https://github.com/freepotato/Milla-Feed/commit/832ff764be794419386c281860eec738b66502ad))
* **ui:** make the feed scrollbar draggable and show the changelog version ([b941227](https://github.com/freepotato/Milla-Feed/commit/b941227e87a6f0debebc4734f0a3d9a52ebb05b7))


### Reverts

* **home:** use the native scroll indicator instead of the custom bar ([c5fa08e](https://github.com/freepotato/Milla-Feed/commit/c5fa08e4aff837acc099bc3bc127bb1c59847c15))

## [0.1.1](https://github.com/freepotato/Milla-Feed/compare/v0.1.0...v0.1.1) (2026-10-28)


### Features

* **app:** add light/dark/system appearance mode ([c98ba78](https://github.com/freepotato/Milla-Feed/commit/c98ba78557cc75b2fc0d39a76d4e560dcffad179))
* **app:** add remoshuang feed, default to 10 daily / 2 sampled per source ([e805128](https://github.com/freepotato/Milla-Feed/commit/e8051281d6ad4d6e58c4a7bab22dcbcc24454879))
* **app:** append-only home feed ordering and centered-M icon ([e4a310e](https://github.com/freepotato/Milla-Feed/commit/e4a310ee09d42d9c3ccb68bc799153ec5f0709df))
* **app:** bottom tab navigation, swipe-to-switch news categories, copy title ([78990c4](https://github.com/freepotato/Milla-Feed/commit/78990c42d99cd0a8896505526ca5ccd3cc3cffcf))
* **app:** favorites list and banner search box ([2b271f8](https://github.com/freepotato/Milla-Feed/commit/2b271f8f7e3336e4da1044f13b8af09fa8e0bf37))
* **app:** hourly refresh from remoshuang homepage hot board ([b86674d](https://github.com/freepotato/Milla-Feed/commit/b86674d784aea6a38f8d74a8feebf72933490c72))
* **app:** newspaper app icon and Chinese default feeds ([13b4af4](https://github.com/freepotato/Milla-Feed/commit/13b4af47e55645d95b213da244fc366c95ab0590))
* **app:** source daily news from remoshuang today-events API ([edf39ec](https://github.com/freepotato/Milla-Feed/commit/edf39ecaa5e5ddbb989094ba7f75c5bdd4312bdc))
* **app:** swipe right from left edge to exit daily news ([4fd1ded](https://github.com/freepotato/Milla-Feed/commit/4fd1ded854abbcaff1b4e04c99201b600a0ecc7e))
* **app:** twice-daily news digest page with one-line summaries ([9227c86](https://github.com/freepotato/Milla-Feed/commit/9227c86ef2b59c24d3f8ce08a98c4f69d4b292ce))
* **app:** wrap icon M with side text lines and clean bottom ([d11d5e6](https://github.com/freepotato/Milla-Feed/commit/d11d5e655ba292c0cec11de7cb471be279aecbb9))
* **core:** add ContentSanitizer for reader-mode cleanup ([2e7078c](https://github.com/freepotato/Milla-Feed/commit/2e7078ccbbb077d3ebddf0e858c84ca2d912ab30))
* **core:** per-source timeliness/depth focus in ranking ([5eb68b1](https://github.com/freepotato/Milla-Feed/commit/5eb68b1b47043e3d896614f260b1b5c81e45513b))
* **core:** strip duplicated editor intro at article start ([838a184](https://github.com/freepotato/Milla-Feed/commit/838a1847f1fd67408b800748e7a7ad3939a9986b))
* **reader:** keep trailing read-more link tappable in article body ([3e2d803](https://github.com/freepotato/Milla-Feed/commit/3e2d8038e42a9cad43b8bee54f7039b8aa98d62e))
* **settings:** replace technical rows with an in-app changelog ([607611b](https://github.com/freepotato/Milla-Feed/commit/607611b316fb09ecfd6aaed7d73f2018299916ce))
* **ui:** replace smile arc with three feed lines under icon wordmark ([433bf5a](https://github.com/freepotato/Milla-Feed/commit/433bf5a624b67e73667d4613a4d37791eb4807d9))
* **ui:** two-tone purple icon with white Milla wordmark ([9c32c25](https://github.com/freepotato/Milla-Feed/commit/9c32c25b60fffb297543935e5d9002a6772805e0))


### Bug Fixes

* **app:** clear navigation stack on daily-news edge swipe ([b1379ec](https://github.com/freepotato/Milla-Feed/commit/b1379ecb1e43f01f0d0ea7a0312526278341f7fe))
* **app:** constrain reader images and restore HTML typography ([846f86e](https://github.com/freepotato/Milla-Feed/commit/846f86e3c5107996382d42d9b2b6f23ef8e7ce37))
* **app:** re-check hourly refresh each time the news tab opens ([d650bed](https://github.com/freepotato/Milla-Feed/commit/d650bed283f4abb66afbb977d46b9a6b004b4c7b))
* **app:** resolve compile errors against iOS 27 SDK ([91ed6de](https://github.com/freepotato/Milla-Feed/commit/91ed6deb04393d1561191cd93e093226d3d6d55d))
* **app:** set ALWAYS_SEARCH_USER_PATHS=NO and ONLY_ACTIVE_ARCH=YES ([b4f885e](https://github.com/freepotato/Milla-Feed/commit/b4f885e67fc27f63a8918adcb43daaf4d9934df4))
* **app:** show original article titles in daily news entries ([88a5a22](https://github.com/freepotato/Milla-Feed/commit/88a5a22753ba65a4b7073be59985c8a2968a0216))
* **app:** single width-fit cover, linkless body, refreshed stored content ([4d7dc6b](https://github.com/freepotato/Milla-Feed/commit/4d7dc6b57f431b975092158a58caa8c8e32ffe8d))
* **app:** stop HTMLTextView from blowing out reader layout ([ef9a111](https://github.com/freepotato/Milla-Feed/commit/ef9a111cdb860f784966b9cf17fa2b93cf34fb64))
* **app:** wrap attributed text in unchecked Sendable box for @Sendable capture ([525e653](https://github.com/freepotato/Milla-Feed/commit/525e653a4e2fb32fd9d0adbbcfa4d26a43821de6))
* **core:** prefer atom alternate links on Linux ([44c05b4](https://github.com/freepotato/Milla-Feed/commit/44c05b44da80db8318382fff7bbf05fa7ba815a6))
* **core:** strip script/style content from HTML plain text ([b60c856](https://github.com/freepotato/Milla-Feed/commit/b60c856c16799d77c25f904a01a8f1981fc888a4))
* **news:** match remoshuang homepage combined board and category order ([b27cbb8](https://github.com/freepotato/Milla-Feed/commit/b27cbb813637f9633f27c2792b913449018b57c9))
* **reader:** replace deprecated UITextItemInteraction delegate ([c9384af](https://github.com/freepotato/Milla-Feed/commit/c9384aff37e89dfb98051235d3c97de0ad0a7742))
* **release:** keep project.yml formatting when bumping the app version ([729febd](https://github.com/freepotato/Milla-Feed/commit/729febd9d3fd9df8c19a9a9d9f0fbf43848bf491))


### Performance Improvements

* **app:** cache and downsample cover images, async reader rendering ([fdedcd6](https://github.com/freepotato/Milla-Feed/commit/fdedcd64ecb28105ec86bc28bb9e1ff8e5d1a2f3))
