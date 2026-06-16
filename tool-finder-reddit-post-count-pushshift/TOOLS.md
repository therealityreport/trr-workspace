# Reddit Archive Count Tool Options

Tool Finder implementation candidates for `Pushshift Arctic Shift Reddit submissions dataset subreddit submission count CLI repository`.

Use this file as the working shortlist for tools, repositories, models, packages, or features to implement fully, integrate partially, or borrow from.

## Coverage

- Results: `12`
- Raw results: `12`
- Skipped providers: `3`
- Ranked results: `12`

## Implementation Shortlist

| Rank | Candidate | Source | Type | Consider As | Best Action | Why Consider | Use Path | Risk / Note |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | [arctic](https://pypi.org/project/arctic/) | Python Packages | library | Partially integrate | dry-run-install-plan | Ranked #1 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `python -m pip install Arctic` | Python package install is not executed automatically. |
| 2 | [Shift](https://pypi.org/project/Shift/) | Python Packages | library | Partially integrate | dry-run-install-plan | Ranked #2 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `python -m pip install Shift` | Python package install is not executed automatically. |
| 3 | [adr-tools](https://formulae.brew.sh/formula/adr-tools) | Homebrew | cli | Partially integrate | dry-run-install-plan | Ranked #3 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `brew install adr-tools` | Homebrew install is not executed automatically. |
| 4 | [argus-clients](https://formulae.brew.sh/formula/argus-clients) | Homebrew | cli | Partially integrate | dry-run-install-plan | Ranked #4 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `brew install argus-clients` | Homebrew install is not executed automatically. |
| 5 | [awsweeper](https://formulae.brew.sh/formula/awsweeper) | Homebrew | cli | Partially integrate | dry-run-install-plan | Ranked #5 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `brew install awsweeper` | Homebrew install is not executed automatically. |
| 6 | [backplane-cli](https://formulae.brew.sh/formula/backplane-cli) | Homebrew | cli | Partially integrate | dry-run-install-plan | Ranked #6 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `brew install backplane-cli` | Homebrew install is not executed automatically. |
| 7 | [execline](https://formulae.brew.sh/formula/execline) | Homebrew | cli | Partially integrate | dry-run-install-plan | Ranked #7 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `brew install execline` | Homebrew install is not executed automatically. |
| 8 | [rawfilejson/awesome-osint-arsenal/README.md](https://github.com/rawfilejson/awesome-osint-arsenal/blob/1f1accb7bc9570a14263d31ca8d5e2d52f50f8a7/README.md) | GitHub Code Search | unknown | Reference only | reference-only | Ranked #8 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `https://github.com/rawfilejson/awesome-osint-arsenal/blob/1f1accb7bc9570a14263d31ca8d5e2d52f50f8a7/README.md` | Do not execute remote code from search results without manual review. |
| 9 | [19-84/redd-archiver/reddarc.py](https://github.com/19-84/redd-archiver/blob/60c6c697e316a5f25bdc022d2467ffb1d7971f86/reddarc.py) | GitHub Code Search | unknown | Reference only | reference-only | Ranked #9 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `https://github.com/19-84/redd-archiver/blob/60c6c697e316a5f25bdc022d2467ffb1d7971f86/reddarc.py` | Do not execute remote code from search results without manual review. |
| 10 | [sohamthirty/Stock-Price-Prediction-with-Sentiment-Analysis/Sentiment Analysis/Scrape_RedditPosts.ipynb](https://github.com/sohamthirty/Stock-Price-Prediction-with-Sentiment-Analysis/blob/3eb88064f53e7fcafec811a3a81c6db4054580f3/Sentiment%20Analysis/Scrape_RedditPosts.ipynb) | GitHub Code Search | unknown | Reference only | reference-only | Ranked #10 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `https://github.com/sohamthirty/Stock-Price-Prediction-with-Sentiment-Analysis/blob/3eb88064f53e7fcafec811a3a81c6db4054580f3/Sentiment%20Analysis/Scrape_RedditPosts.ipynb` | Do not execute remote code from search results without manual review. |
| 11 | [lethuyvan/thesis-work-source/reddit/crawled_data/thecodingdude.txt](https://github.com/lethuyvan/thesis-work-source/blob/ab1e1b34a094d6bc288fd6ad92fcfe7dc9243493/reddit/crawled_data/thecodingdude.txt) | GitHub Code Search | unknown | Reference only | reference-only | Ranked #11 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `https://github.com/lethuyvan/thesis-work-source/blob/ab1e1b34a094d6bc288fd6ad92fcfe7dc9243493/reddit/crawled_data/thecodingdude.txt` | Do not execute remote code from search results without manual review. |
| 12 | [ivangermanov/openml-tags/notebooks/evaluation/openml/vocabulary.txt](https://github.com/ivangermanov/openml-tags/blob/d3bdea2a2611f223192222aa99cd0130ef887e43/notebooks/evaluation/openml/vocabulary.txt) | GitHub Code Search | unknown | Reference only | reference-only | Ranked #12 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. | `https://github.com/ivangermanov/openml-tags/blob/d3bdea2a2611f223192222aa99cd0130ef887e43/notebooks/evaluation/openml/vocabulary.txt` | Do not execute remote code from search results without manual review. |

## Candidates By Type

### CLI ([details](types/cli.html))

| Rank | Candidate | Source | Consider As | Feature / Capability To Carry Forward |
| ---: | --- | --- | --- | --- |
| 3 | [adr-tools](https://formulae.brew.sh/formula/adr-tools) | [Homebrew](sources/homebrew.html) | Partially integrate | CLI tool for working with Architecture Decision Records; executables: _adr_add_link, _adr_autocomplete, _adr_commands, _adr_dir, _adr_file, _adr_generate_graph, _adr_generate_toc, _adr_help, _adr_help_new, _adr_links, _adr_remove_status, _adr_status, _adr_title, adr, adr-config, adr-generate, adr-help, adr-init, adr-link, adr-list, adr-new, adr-upgrade-repository |
| 4 | [argus-clients](https://formulae.brew.sh/formula/argus-clients) | [Homebrew](sources/homebrew.html) | Partially integrate | Audit Record Generation and Utilization System clients; executables: argusclientbug, ra, rabins, racluster, racount, radium, ramanage, ranonymize, rasort, rastream; dependencies: readline, rrdtool |
| 5 | [awsweeper](https://formulae.brew.sh/formula/awsweeper) | [Homebrew](sources/homebrew.html) | Partially integrate | CLI tool for cleaning your AWS account; executables: awsweeper |
| 6 | [backplane-cli](https://formulae.brew.sh/formula/backplane-cli) | [Homebrew](sources/homebrew.html) | Partially integrate | CLI for interacting with the OpenShift Backplane API; executables: ocm-backplane |
| 7 | [execline](https://formulae.brew.sh/formula/execline) | [Homebrew](sources/homebrew.html) | Partially integrate | Interpreter-less scripting language; executables: background, backtick, case, cd, define, dollarat, elgetopt, elgetpositionals, elglob, eltest, emptyenv, envfile, exec, execline-cd, execline-umask, execlineb, exit, export, export-array, fdblock, fdclose, fdmove, fdreserve, fdswap, forbacktickx, foreground, forstdin, forx, getcwd, getpid, heredoc, homeof, if, ifelse, ifte, ifthenelse, importas, loopwhilex, multidefine, multisubstitute, pipeline, piperw, posix-cd, posix-umask, redirfd, runblock, shift, trap, tryexec, umask, unexport, wait, withstdinas; dependencies: skalibs |

### PACKAGES ([details](types/packages.html))

| Rank | Candidate | Source | Consider As | Feature / Capability To Carry Forward |
| ---: | --- | --- | --- | --- |
| 1 | [arctic](https://pypi.org/project/arctic/) | [Python Packages](sources/python.html) | Partially integrate | AHL Research Versioned TimeSeries and Tick store; keywords: ahl,keyvalue,tickstore,mongo,timeseries; pip dry-run: python -m pip install --dry-run --report - Arctic |
| 2 | [Shift](https://pypi.org/project/Shift/) | [Python Packages](sources/python.html) | Partially integrate | A generic template library for Python; pip dry-run: python -m pip install --dry-run --report - Shift |

### OTHER ([details](types/other.html))

| Rank | Candidate | Source | Consider As | Feature / Capability To Carry Forward |
| ---: | --- | --- | --- | --- |
| 8 | [rawfilejson/awesome-osint-arsenal/README.md](https://github.com/rawfilejson/awesome-osint-arsenal/blob/1f1accb7bc9570a14263d31ca8d5e2d52f50f8a7/README.md) | [GitHub Code Search](sources/github-code.html) | Reference only | Ranked #8 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. |
| 9 | [19-84/redd-archiver/reddarc.py](https://github.com/19-84/redd-archiver/blob/60c6c697e316a5f25bdc022d2467ffb1d7971f86/reddarc.py) | [GitHub Code Search](sources/github-code.html) | Reference only | Ranked #9 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. |
| 10 | [sohamthirty/Stock-Price-Prediction-with-Sentiment-Analysis/Sentiment Analysis/Scrape_RedditPosts.ipynb](https://github.com/sohamthirty/Stock-Price-Prediction-with-Sentiment-Analysis/blob/3eb88064f53e7fcafec811a3a81c6db4054580f3/Sentiment%20Analysis/Scrape_RedditPosts.ipynb) | [GitHub Code Search](sources/github-code.html) | Reference only | Ranked #10 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. |
| 11 | [lethuyvan/thesis-work-source/reddit/crawled_data/thecodingdude.txt](https://github.com/lethuyvan/thesis-work-source/blob/ab1e1b34a094d6bc288fd6ad92fcfe7dc9243493/reddit/crawled_data/thecodingdude.txt) | [GitHub Code Search](sources/github-code.html) | Reference only | Ranked #11 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. |
| 12 | [ivangermanov/openml-tags/notebooks/evaluation/openml/vocabulary.txt](https://github.com/ivangermanov/openml-tags/blob/d3bdea2a2611f223192222aa99cd0130ef887e43/notebooks/evaluation/openml/vocabulary.txt) | [GitHub Code Search](sources/github-code.html) | Reference only | Ranked #12 after final scoring across all providers, dedupe, availability, provider source, safety, and maintenance signals. |

## Candidates By Adoption Scope

### Partially integrate

| Rank | Candidate | Source | Best Action | Use Path |
| ---: | --- | --- | --- | --- |
| 1 | [arctic](https://pypi.org/project/arctic/) | Python Packages | dry-run-install-plan | `python -m pip install Arctic` |
| 2 | [Shift](https://pypi.org/project/Shift/) | Python Packages | dry-run-install-plan | `python -m pip install Shift` |
| 3 | [adr-tools](https://formulae.brew.sh/formula/adr-tools) | Homebrew | dry-run-install-plan | `brew install adr-tools` |
| 4 | [argus-clients](https://formulae.brew.sh/formula/argus-clients) | Homebrew | dry-run-install-plan | `brew install argus-clients` |
| 5 | [awsweeper](https://formulae.brew.sh/formula/awsweeper) | Homebrew | dry-run-install-plan | `brew install awsweeper` |
| 6 | [backplane-cli](https://formulae.brew.sh/formula/backplane-cli) | Homebrew | dry-run-install-plan | `brew install backplane-cli` |
| 7 | [execline](https://formulae.brew.sh/formula/execline) | Homebrew | dry-run-install-plan | `brew install execline` |

### Reference only

| Rank | Candidate | Source | Best Action | Use Path |
| ---: | --- | --- | --- | --- |
| 8 | [rawfilejson/awesome-osint-arsenal/README.md](https://github.com/rawfilejson/awesome-osint-arsenal/blob/1f1accb7bc9570a14263d31ca8d5e2d52f50f8a7/README.md) | GitHub Code Search | reference-only | `https://github.com/rawfilejson/awesome-osint-arsenal/blob/1f1accb7bc9570a14263d31ca8d5e2d52f50f8a7/README.md` |
| 9 | [19-84/redd-archiver/reddarc.py](https://github.com/19-84/redd-archiver/blob/60c6c697e316a5f25bdc022d2467ffb1d7971f86/reddarc.py) | GitHub Code Search | reference-only | `https://github.com/19-84/redd-archiver/blob/60c6c697e316a5f25bdc022d2467ffb1d7971f86/reddarc.py` |
| 10 | [sohamthirty/Stock-Price-Prediction-with-Sentiment-Analysis/Sentiment Analysis/Scrape_RedditPosts.ipynb](https://github.com/sohamthirty/Stock-Price-Prediction-with-Sentiment-Analysis/blob/3eb88064f53e7fcafec811a3a81c6db4054580f3/Sentiment%20Analysis/Scrape_RedditPosts.ipynb) | GitHub Code Search | reference-only | `https://github.com/sohamthirty/Stock-Price-Prediction-with-Sentiment-Analysis/blob/3eb88064f53e7fcafec811a3a81c6db4054580f3/Sentiment%20Analysis/Scrape_RedditPosts.ipynb` |
| 11 | [lethuyvan/thesis-work-source/reddit/crawled_data/thecodingdude.txt](https://github.com/lethuyvan/thesis-work-source/blob/ab1e1b34a094d6bc288fd6ad92fcfe7dc9243493/reddit/crawled_data/thecodingdude.txt) | GitHub Code Search | reference-only | `https://github.com/lethuyvan/thesis-work-source/blob/ab1e1b34a094d6bc288fd6ad92fcfe7dc9243493/reddit/crawled_data/thecodingdude.txt` |
| 12 | [ivangermanov/openml-tags/notebooks/evaluation/openml/vocabulary.txt](https://github.com/ivangermanov/openml-tags/blob/d3bdea2a2611f223192222aa99cd0130ef887e43/notebooks/evaluation/openml/vocabulary.txt) | GitHub Code Search | reference-only | `https://github.com/ivangermanov/openml-tags/blob/d3bdea2a2611f223192222aa99cd0130ef887e43/notebooks/evaluation/openml/vocabulary.txt` |

## Source / Type Detail Pages

- [GitHub Code Search: OTHER](source-types/github-code/other.html)
- [Homebrew: CLI](source-types/homebrew/cli.html)
- [Python Packages: PACKAGES](source-types/python/packages.html)

## Provider Coverage

| Provider | Results | State | Reason | Remediation |
| --- | ---: | --- | --- | --- |
| runtime:catalog (skipped) | 0 | skipped | No runtime catalog JSON was supplied to the all-provider command. | Pass --runtime-catalog with a live Codex tool catalog JSON file when running outside an assistant turn. |
| skills.sh:search (skipped) | 0 | skipped | No Vercel OIDC token available for skills.sh. | Link a Vercel project that can provide OIDC auth.<br>Set VERCEL_OIDC_TOKEN for this request. |
| github:repositories (queried) | 0 | queried | github provider completed. |  |
| github:code (queried) | 5 | queried | github provider completed. |  |
| npm:search (error) | 0 | error | npm request failed | Check network access, provider auth, and the provider helper script. |
| python:search (queried) | 2 | queried | python provider completed. |  |
| homebrew:search (queried) | 5 | queried | homebrew provider completed. |  |
| hugging-face:models (queried) | 0 | queried | Hugging Face Hub public API lookup completed. |  |
| hugging-face:datasets (queried) | 0 | queried | Hugging Face Hub public API lookup completed. |  |
| hugging-face:spaces (queried) | 0 | queried | Hugging Face Hub public API lookup completed. |  |
| package-registry-plan (queried) | 0 | queried | Package registry provider plan completed. |  |

## Skipped Sources

| Provider | Results | State | Reason | Remediation |
| --- | ---: | --- | --- | --- |
| runtime:catalog (skipped) | 0 | skipped | No runtime catalog JSON was supplied to the all-provider command. | Pass --runtime-catalog with a live Codex tool catalog JSON file when running outside an assistant turn. |
| skills.sh:search (skipped) | 0 | skipped | No Vercel OIDC token available for skills.sh. | Link a Vercel project that can provide OIDC auth.<br>Set VERCEL_OIDC_TOKEN for this request. |
| npm:search (error) | 0 | error | npm request failed | Check network access, provider auth, and the provider helper script. |
