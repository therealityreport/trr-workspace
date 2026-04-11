# TikTok Browser Intercept Drift Disambiguation

Date: 2026-04-10

## Target

`@bravotv`

## Inputs

- `/Users/thomashulihan/Projects/TRR/.planning/research/TIKTOK_BROWSER_INTERCEPT_RECOVERY_TRIAGE_2026-04-10.md`
- `/tmp/tiktok-browser-intercept-drift-20260410/summary.json`
- `/tmp/tiktok-browser-intercept-drift-20260410/bravotv-main.html`

## Selector Drift

Selector drift was not observed. The rendered `<main>` snapshot contained no `/video/` links, no post-card `data-e2e` nodes, and no alternate post-like DOM subtree that looked like hidden content our current selectors simply miss. A follow-up capture after five scrolls only surfaced a shell tab node (`data-e2e="repost-tab"`), not actual post cards, so there is no evidence that posts are present in the DOM under a different selector.

## Pagination Drift

Pagination drift was observed. The page made real TikTok fetch/XHR traffic during load and the first scroll, including `GET /api/post/item_list/` on initial load, `GET /api/user/playlist/`, `GET /api/story/item_list/`, and `GET /api/repost/item_list/` after the first scroll. The important split is that the main posts request (`/api/post/item_list/`) returned `200` with `content-type=application/json` but was not JSON-parseable in the browser capture, while `/api/repost/item_list/` returned a normal JSON payload with `itemList`. That means the page is still using network pagination patterns, but the request/response shape we need for post cards is no longer usable under the current intercept assumptions.

## Scroll Drift

Pure scroll drift was not observed. Scrolling did trigger additional network activity, especially on the first scroll, so the page is not completely ignoring the interaction. What did not happen is any growth in document height, any appearance of real post-card DOM nodes, or any usable post-list payload after the scroll loop. That points away from “scroll is not firing anything” and toward “scroll fires, but the post pagination path is no longer yielding usable post data.”

Confirmed bucket: `pagination_drift` (not selector drift, not pure scroll drift). The implied fix class is browser-intercept request/response adaptation: identify and handle the current post-feed request/response pattern instead of spending the next pass on DOM selector changes or more elaborate interaction scripting.

## Response Body Capture — /api/post/item_list/

- HTTP status: `200`
- Request URL: `https://www.tiktok.com/api/post/item_list/?WebIdLastTime=1772893072&aid=1988&app_language=en&app_name=tiktok_web&browser_language=en-US&browser_name=Mozilla&browser_online=true&browser_platform=MacIntel&browser_version=5.0%20%28Macintosh%3B%20Intel%20Mac%20OS%20X%2010_15_7%29%20AppleWebKit%2F537.36%20%28KHTML%2C%20like%20Gecko%29%20Chrome%2F144.0.0.0%20Safari%2F537.36&channel=tiktok_web&cookie_enabled=true&count=35&coverFormat=2&cursor=0&data_collection_enabled=true&device_id=7614517726053271054&device_platform=web_pc&focus_state=true&history_len=2&is_fullscreen=false&is_page_visible=true&language=en&odinId=7614517125889541133&os=mac&priority_region=US&referer=&region=US&screen_height=900&screen_width=1280&secUid=MS4wLjABAAAAPCEnSMIAOyPpQ03mDa-LwpXdbscJ_5ef9QnEPDeatI24o-PxdOhGcx7BLeglzQIA&tz_name=America%2FNew_York&user_is_login=true&verifyFp=verify_mmgesh9c_1xQXZi3b_7Z2m_4Ql6_92ID_hSKRbb396W1K&video_encoding=mp4&webcast_language=en&msToken=&X-Bogus=DFSzsIVOnSbANCc4Co9c8TVxWZ9A&X-Gnarly=M8uGaRdCWLz9/JGiXThHrEO9KgJNtut1X0WdWxwUXXT1OAF4MeeTxVOU6S3pDnr0dcGWgkD5LAyke7a4mgkexJCY3NwNDtijC18sMS2ZJcbXXuQY-OKQMLD-DhltUS0ABQL-OmKMRbhQ3nj1y9T50EFfeYI8c0OyZB2uJY6P04Sr-eIsVTNQ7/BCH9zl1l956Erw3CkJMbW-m/KzN75tnFXbqfGxJJSdUPuQWL0gzQppoMmrrqRRveqM0Qd3ZTPJ71dAeisKhOJXEcj1nAI7AUqDrpTwC4b4UrMaUIdjcp/FOJZILQmni-znSj37486lMGNzt5CZuk==`
- Request headers:

```json
{
  "sec-ch-ua-platform": "\"macOS\"",
  "referer": "https://www.tiktok.com/@bravotv",
  "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36",
  "sec-ch-ua": "\"Chromium\";v=\"146\", \"Not-A.Brand\";v=\"24\", \"Google Chrome\";v=\"146\"",
  "sec-ch-ua-mobile": "?0"
}
```

- Response headers:

```json
{
  "x-ms-token": "65OJAthm7jbb0uJqp8EmICe-UhH1_KF0obMOqhaai34TYzlgzroAyH_FK4JVjmgZQabZG1SvjQnN5wO2f0oq_3rp1yrLzhfZtdWS2SdgJX5Foffvf6_wCjn3zr2nOhgXWpV_q5oNr5ojAWOny9XydFwhlA==",
  "tt-ticket-guard-result": "0",
  "access-control-expose-headers": "x-tt-traceflag,x-tt-logid",
  "expires": "Fri, 10 Apr 2026 22:49:01 GMT",
  "server-timing": "inner; dur=24, cdn-cache; desc=MISS, edge; dur=1, origin; dur=50",
  "x-cache": "TCP_MISS from a23-209-189-140.deploy.akamaitechnologies.com (AkamaiGHost/22.4.5-f6127473d93ee4320e9a40154546bf6e) (-)",
  "date": "Fri, 10 Apr 2026 22:49:01 GMT",
  "content-type": "application/json",
  "x-vc-bdturing-parameters": "{\"code\":\"10000\",\"from\":\"\",\"type\":\"verify\",\"version\":\"\",\"region\":\"ttp2\",\"subtype\":\"3d\",\"ui_type\":\"\",\"detail\":\"OIrtpmYlN*SBP8q7bBVevvmCnQnWjHMTHyg3Kmoe6JskvuS4t4bX1yUrA30iwE0i7fN1SMwxZmbllK6FSDxtQJeSgJ8Tw-*9X-wUKC3nLuoc5Z9X9GoEOxltLmoM0nXBq228Ok1FPUCOMXa1Gf56qwQkFj48eqbUdOwAeZosm8WufS2OQOklVemOJTl2yjpNcqsQCXsvaSrbx0vc6BXLuxdd-hop65IS3Iz0YKNKW78wFf6b1HpDvSuW5j9zvJpJ7FVu0s6WpLC623AFSjJKj3JIoskx1ajzQ6dfDFAjRBs4GxAZXDlDtORRIGO6VSroy4f8QiAh0lNTT3cnNL4O07QOQ5lwz6Nuk85r5fGQmZR465Qf8cDHozzaXyhMthgM0nDKLj*93ez7JtZyoStdtAWFN5v9D9g*PSqDT1DM8*2ltZVLdzX9yB1fHDKCjlnMXRLDZ6xffk64JWCl3OsZTH-pyDty-g..\",\"verify_event\":\"\",\"fp\":\"verify_mmgesh9c_1xQXZi3b_7Z2m_4Ql6_92ID_hSKRbb396W1K\",\"server_sdk_env\":\"{\\\"idc\\\":\\\"useast8\\\",\\\"region\\\":\\\"US-TTP2\\\",\\\"server_type\\\":\\\"business\\\"}\",\"log_id\":\"20260410224901E2C2BAD87FF731073CBD\",\"is_assist_mobile\":false,\"is_complex_sms\":false,\"identity_action\":\"\",\"identity_scene\":\"\"}",
  "x-akamai-request-id": "622cb49e",
  "tt_stable": "1",
  "x-tt-trace-host": "01639b243d99bc43628835333e3b57751e4a8039ef494b457fb3f3ccd0541a7bc9c7f4344a855287e9d41fb8d9ebedfb0db0edb38778d3e2488a0f043c94f575d70bb279e5680dd1e521bf46d0c437827d751ccaa3b21fa5ca0ceea267a17333eb",
  "x-origin-response-time": "50,23.209.189.140",
  "cache-control": "max-age=0, no-cache, no-store",
  "pragma": "no-cache",
  "bdturing-verify": "{\"code\":\"10000\",\"from\":\"\",\"type\":\"verify\",\"version\":\"\",\"region\":\"ttp2\",\"subtype\":\"3d\",\"ui_type\":\"\",\"detail\":\"OIrtpmYlN*SBP8q7bBVevvmCnQnWjHMTHyg3Kmoe6JskvuS4t4bX1yUrA30iwE0i7fN1SMwxZmbllK6FSDxtQJeSgJ8Tw-*9X-wUKC3nLuoc5Z9X9GoEOxltLmoM0nXBq228Ok1FPUCOMXa1Gf56qwQkFj48eqbUdOwAeZosm8WufS2OQOklVemOJTl2yjpNcqsQCXsvaSrbx0vc6BXLuxdd-hop65IS3Iz0YKNKW78wFf6b1HpDvSuW5j9zvJpJ7FVu0s6WpLC623AFSjJKj3JIoskx1ajzQ6dfDFAjRBs4GxAZXDlDtORRIGO6VSroy4f8QiAh0lNTT3cnNL4O07QOQ5lwz6Nuk85r5fGQmZR465Qf8cDHozzaXyhMthgM0nDKLj*93ez7JtZyoStdtAWFN5v9D9g*PSqDT1DM8*2ltZVLdzX9yB1fHDKCjlnMXRLDZ6xffk64JWCl3OsZTH-pyDty-g..\",\"verify_event\":\"\",\"fp\":\"verify_mmgesh9c_1xQXZi3b_7Z2m_4Ql6_92ID_hSKRbb396W1K\",\"server_sdk_env\":\"{\\\"idc\\\":\\\"useast8\\\",\\\"region\\\":\\\"US-TTP2\\\",\\\"server_type\\\":\\\"business\\\"}\",\"log_id\":\"20260410224901E2C2BAD87FF731073CBD\",\"is_assist_mobile\":false,\"is_complex_sms\":false,\"identity_action\":\"\",\"identity_scene\":\"\"}",
  "x-tt-trace-tag": "id=16;cdn-cache=miss;type=dyn",
  "x-tt-trace-id": "00-260410224901E2C2BAD87FF731073CBD-707344AB556C873F-00",
  "content-length": "0",
  "x-tt-logid": "20260410224901E2C2BAD87FF731073CBD",
  "server": "nginx"
}
```

- First ~1KB of response body, raw text: `""`
- First ~1KB of response body, hex: `""`
- Format category: `empty_or_truncated_response`

The `/api/post/item_list/` body matches the empty/truncated-response category. That points the repair session at request-shape or anti-bot response handling, not HTML parsing, decoder work, or binary schema adaptation.
