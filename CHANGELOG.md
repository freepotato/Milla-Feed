# Changelog

## [0.1.1](https://github.com/freepotato/Milla-Feed/compare/v0.1.0...v0.1.1) (2026-10-17)


### Features

* **app:** add light/dark/system appearance mode ([c98ba78](https://github.com/freepotato/Milla-Feed/commit/c98ba78557cc75b2fc0d39a76d4e560dcffad179))
* **app:** add remoshuang feed, default to 10 daily / 2 sampled per source ([e805128](https://github.com/freepotato/Milla-Feed/commit/e8051281d6ad4d6e58c4a7bab22dcbcc24454879))
* **app:** append-only home feed ordering and centered-M icon ([e4a310e](https://github.com/freepotato/Milla-Feed/commit/e4a310ee09d42d9c3ccb68bc799153ec5f0709df))
* **app:** newspaper app icon and Chinese default feeds ([13b4af4](https://github.com/freepotato/Milla-Feed/commit/13b4af47e55645d95b213da244fc366c95ab0590))
* **app:** swipe right from left edge to exit daily news ([4fd1ded](https://github.com/freepotato/Milla-Feed/commit/4fd1ded854abbcaff1b4e04c99201b600a0ecc7e))
* **app:** twice-daily news digest page with one-line summaries ([9227c86](https://github.com/freepotato/Milla-Feed/commit/9227c86ef2b59c24d3f8ce08a98c4f69d4b292ce))
* **app:** wrap icon M with side text lines and clean bottom ([d11d5e6](https://github.com/freepotato/Milla-Feed/commit/d11d5e655ba292c0cec11de7cb471be279aecbb9))
* **core:** add ContentSanitizer for reader-mode cleanup ([2e7078c](https://github.com/freepotato/Milla-Feed/commit/2e7078ccbbb077d3ebddf0e858c84ca2d912ab30))
* **core:** per-source timeliness/depth focus in ranking ([5eb68b1](https://github.com/freepotato/Milla-Feed/commit/5eb68b1b47043e3d896614f260b1b5c81e45513b))
* **core:** strip duplicated editor intro at article start ([838a184](https://github.com/freepotato/Milla-Feed/commit/838a1847f1fd67408b800748e7a7ad3939a9986b))
* **ui:** replace smile arc with three feed lines under icon wordmark ([433bf5a](https://github.com/freepotato/Milla-Feed/commit/433bf5a624b67e73667d4613a4d37791eb4807d9))
* **ui:** two-tone purple icon with white Milla wordmark ([9c32c25](https://github.com/freepotato/Milla-Feed/commit/9c32c25b60fffb297543935e5d9002a6772805e0))


### Bug Fixes

* **app:** clear navigation stack on daily-news edge swipe ([b1379ec](https://github.com/freepotato/Milla-Feed/commit/b1379ecb1e43f01f0d0ea7a0312526278341f7fe))
* **app:** constrain reader images and restore HTML typography ([846f86e](https://github.com/freepotato/Milla-Feed/commit/846f86e3c5107996382d42d9b2b6f23ef8e7ce37))
* **app:** resolve compile errors against iOS 27 SDK ([91ed6de](https://github.com/freepotato/Milla-Feed/commit/91ed6deb04393d1561191cd93e093226d3d6d55d))
* **app:** set ALWAYS_SEARCH_USER_PATHS=NO and ONLY_ACTIVE_ARCH=YES ([b4f885e](https://github.com/freepotato/Milla-Feed/commit/b4f885e67fc27f63a8918adcb43daaf4d9934df4))
* **app:** show original article titles in daily news entries ([88a5a22](https://github.com/freepotato/Milla-Feed/commit/88a5a22753ba65a4b7073be59985c8a2968a0216))
* **app:** single width-fit cover, linkless body, refreshed stored content ([4d7dc6b](https://github.com/freepotato/Milla-Feed/commit/4d7dc6b57f431b975092158a58caa8c8e32ffe8d))
* **app:** stop HTMLTextView from blowing out reader layout ([ef9a111](https://github.com/freepotato/Milla-Feed/commit/ef9a111cdb860f784966b9cf17fa2b93cf34fb64))
* **app:** wrap attributed text in unchecked Sendable box for @Sendable capture ([525e653](https://github.com/freepotato/Milla-Feed/commit/525e653a4e2fb32fd9d0adbbcfa4d26a43821de6))
* **core:** prefer atom alternate links on Linux ([44c05b4](https://github.com/freepotato/Milla-Feed/commit/44c05b44da80db8318382fff7bbf05fa7ba815a6))
* **core:** strip script/style content from HTML plain text ([b60c856](https://github.com/freepotato/Milla-Feed/commit/b60c856c16799d77c25f904a01a8f1981fc888a4))


### Performance Improvements

* **app:** cache and downsample cover images, async reader rendering ([fdedcd6](https://github.com/freepotato/Milla-Feed/commit/fdedcd64ecb28105ec86bc28bb9e1ff8e5d1a2f3))
