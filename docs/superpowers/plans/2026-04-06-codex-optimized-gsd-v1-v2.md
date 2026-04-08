# Codex-Optimized GSD v1 + v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a maintainable Codex-native GSD build pipeline that can install either a `v1` compatibility track or a `v2` native track into `~/.codex` without hand-editing installed skills and agents.

**Architecture:** Build a dedicated source workspace at `/Users/thomashulihan/Projects/gsd-codex` that treats the current `~/.codex` install as input, not source-of-truth. `v1` is generated from the existing GSD workflow and installed artifact patterns; `v2` is authored as a native Codex registry for the core orchestration path (`gsd-do`, `gsd-plan-phase`, `gsd-execute-phase`, `gsd-autonomous`, and their main agents), then rendered and installed through the same sync pipeline.

**Tech Stack:** Node.js CommonJS, `node:test`, filesystem-driven generators, Markdown/TOML emitters, JSON manifest validation.

---

## Assumptions

- Implementation happens in a new dedicated worktree-like source folder: `/Users/thomashulihan/Projects/gsd-codex`.
- The existing install under `/Users/thomashulihan/.codex` remains the runtime target.
- The current GSD workflow canon is under `/Users/thomashulihan/.codex/get-shit-done`.
- `v1` means compatibility generation from the current GSD install shape.
- `v2` means Codex-native skill and agent definitions for the core routing, planning, and execution loop only. Remaining commands stay on `v1` until promoted later.

## File Structure

- Create `/Users/thomashulihan/Projects/gsd-codex/package.json` — local scripts for test, build, and sync.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/config/paths.cjs` — single resolver for source workspace, installed `~/.codex`, and temp test homes.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/catalog/installed-scan.cjs` — reads installed `gsd-*` skills, agents, workflows, and manifest.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/v1/build-skill.cjs` — generates Codex `SKILL.md` from current workflow-driven inputs.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/v1/build-agent.cjs` — generates `.md` and `.toml` pairs for compatibility agents.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/v1/build-all.cjs` — builds the full `v1` artifact tree.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/v2/skill-registry.cjs` — native Codex skill definitions for promoted `v2` commands.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/v2/agent-registry.cjs` — native Codex agent specs for promoted `v2` worker roles.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/v2/render-skill.cjs` — renders registry definitions to installable `SKILL.md`.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/v2/render-agent.cjs` — renders registry definitions to installable `.md` and `.toml`.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/catalog/tracks.cjs` — declares which commands/agents install from `v1` vs `v2`.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/install/sync-to-codex.cjs` — copies the selected track into `~/.codex` or a temp Codex home and regenerates `gsd-file-manifest.json`.
- Create `/Users/thomashulihan/Projects/gsd-codex/src/install/write-manifest.cjs` — deterministic manifest writer for installed files.
- Create `/Users/thomashulihan/Projects/gsd-codex/test/*.test.cjs` — unit and smoke coverage for path resolution, scanning, generation, track selection, and install sync.
- Create `/Users/thomashulihan/Projects/gsd-codex/README.md` — local developer workflow.
- Create `/Users/thomashulihan/Projects/gsd-codex/docs/rollout.md` — how to install `v1` and `v2`, validate, and roll back.

### Task 1: Bootstrap the GSD Codex Source Workspace

**Files:**
- Create: `/Users/thomashulihan/Projects/gsd-codex/package.json`
- Create: `/Users/thomashulihan/Projects/gsd-codex/README.md`
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/config/paths.cjs`
- Test: `/Users/thomashulihan/Projects/gsd-codex/test/bootstrap.paths.test.cjs`

- [ ] **Step 1: Write the failing path-resolution test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const { getPaths } = require('../src/config/paths.cjs');

test('getPaths resolves the GSD source and installed runtime roots', () => {
  const paths = getPaths({
    projectRoot: '/Users/thomashulihan/Projects/gsd-codex',
    codexHome: '/Users/thomashulihan/.codex',
  });

  assert.equal(paths.projectRoot, '/Users/thomashulihan/Projects/gsd-codex');
  assert.equal(paths.codexHome, '/Users/thomashulihan/.codex');
  assert.equal(paths.installedWorkflowRoot, '/Users/thomashulihan/.codex/get-shit-done/workflows');
  assert.equal(paths.installedSkillsRoot, '/Users/thomashulihan/.codex/skills');
  assert.equal(paths.installedAgentsRoot, '/Users/thomashulihan/.codex/agents');
  assert.equal(paths.distRoot, '/Users/thomashulihan/Projects/gsd-codex/dist');
});
```

- [ ] **Step 2: Run the test to confirm the workspace is not bootstrapped yet**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/bootstrap.paths.test.cjs`

Expected: FAIL with `Cannot find module '../src/config/paths.cjs'` or `ENOENT` because the workspace does not exist yet.

- [ ] **Step 3: Create the minimal workspace and path resolver**

```json
{
  "name": "gsd-codex",
  "private": true,
  "type": "commonjs",
  "scripts": {
    "test": "node --test test/*.test.cjs",
    "build:v1": "node -e \"require('./src/v1/build-all.cjs').buildAllV1({ codexHome: process.env.CODEX_HOME || process.env.HOME + '/.codex', outputRoot: './dist/v1' })\"",
    "build:v2": "node -e \"require('./src/v2/build-all.cjs').buildAllV2({ outputRoot: './dist/v2' })\"",
    "sync:v1": "node -e \"require('./src/install/sync-to-codex.cjs').syncTrackToCodex({ projectRoot: process.cwd(), codexHome: process.env.CODEX_HOME || process.env.HOME + '/.codex', track: 'v1' })\"",
    "sync:v2": "node -e \"require('./src/install/sync-to-codex.cjs').syncTrackToCodex({ projectRoot: process.cwd(), codexHome: process.env.CODEX_HOME || process.env.HOME + '/.codex', track: 'v2' })\""
  }
}
```

```md
# gsd-codex

Source workspace for Codex-optimized GSD tracks.

- `v1`: compatibility generation from the current installed GSD workflow surface
- `v2`: native Codex skills and agents for the core GSD orchestration loop
```

```js
const path = require('path');

function getPaths({ projectRoot = process.cwd(), codexHome = path.join(process.env.HOME, '.codex') } = {}) {
  return {
    projectRoot,
    codexHome,
    distRoot: path.join(projectRoot, 'dist'),
    testRoot: path.join(projectRoot, 'test'),
    installedWorkflowRoot: path.join(codexHome, 'get-shit-done', 'workflows'),
    installedTemplateRoot: path.join(codexHome, 'get-shit-done', 'templates'),
    installedSkillsRoot: path.join(codexHome, 'skills'),
    installedAgentsRoot: path.join(codexHome, 'agents'),
    installedManifestPath: path.join(codexHome, 'gsd-file-manifest.json'),
  };
}

module.exports = { getPaths };
```

- [ ] **Step 4: Run the bootstrap test and the full test command**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/bootstrap.paths.test.cjs && npm test`

Expected: PASS with one test passing and `npm test` exiting `0`.

- [ ] **Step 5: Commit the bootstrap**

```bash
cd /Users/thomashulihan/Projects/gsd-codex
git add package.json README.md src/config/paths.cjs test/bootstrap.paths.test.cjs
git commit -m "chore: bootstrap gsd codex source workspace"
```

### Task 2: Catalog the Current Installed GSD Surface

**Files:**
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/catalog/installed-scan.cjs`
- Test: `/Users/thomashulihan/Projects/gsd-codex/test/installed-scan.test.cjs`

- [ ] **Step 1: Write the failing catalog test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const { scanInstalledGsd } = require('../src/catalog/installed-scan.cjs');

test('scanInstalledGsd finds the current GSD skills, agents, workflows, and manifest version', () => {
  const result = scanInstalledGsd({
    codexHome: '/Users/thomashulihan/.codex',
  });

  assert.ok(result.skills.includes('gsd-do'));
  assert.ok(result.skills.includes('gsd-plan-phase'));
  assert.ok(result.agents.includes('gsd-planner'));
  assert.ok(result.agents.includes('gsd-executor'));
  assert.ok(result.workflows.includes('do.md'));
  assert.equal(result.manifest.version, '1.30.0');
});
```

- [ ] **Step 2: Run the test to verify the scanner does not exist**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/installed-scan.test.cjs`

Expected: FAIL with `Cannot find module '../src/catalog/installed-scan.cjs'`.

- [ ] **Step 3: Implement the installed-surface scanner**

```js
const fs = require('fs');
const path = require('path');
const { getPaths } = require('../config/paths.cjs');

function listNames(dir, filter) {
  return fs.readdirSync(dir).filter(filter).sort();
}

function scanInstalledGsd({ codexHome }) {
  const paths = getPaths({ codexHome, projectRoot: process.cwd() });

  const skills = listNames(paths.installedSkillsRoot, name => name.startsWith('gsd-'));
  const agents = listNames(paths.installedAgentsRoot, name => name.startsWith('gsd-'))
    .map(name => name.replace(/\.(md|toml)$/g, ''))
    .filter((name, index, all) => all.indexOf(name) === index)
    .sort();
  const workflows = listNames(paths.installedWorkflowRoot, name => name.endsWith('.md'));
  const manifest = JSON.parse(fs.readFileSync(paths.installedManifestPath, 'utf8'));

  return {
    codexHome,
    skills,
    agents,
    workflows,
    manifest: {
      version: manifest.version,
      timestamp: manifest.timestamp,
      fileCount: Object.keys(manifest.files || {}).length,
    },
  };
}

module.exports = { scanInstalledGsd };
```

- [ ] **Step 4: Run the catalog test and inspect one real payload**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/installed-scan.test.cjs && node -e "console.log(require('./src/catalog/installed-scan.cjs').scanInstalledGsd({ codexHome: '/Users/thomashulihan/.codex' }))"`

Expected: PASS, then a JSON-like object showing `gsd-do`, `gsd-planner`, and manifest version `1.30.0`.

- [ ] **Step 5: Commit the catalog layer**

```bash
cd /Users/thomashulihan/Projects/gsd-codex
git add src/catalog/installed-scan.cjs test/installed-scan.test.cjs
git commit -m "feat: catalog installed gsd surface"
```

### Task 3: Generate the `v1` Compatibility Track

**Files:**
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/v1/build-skill.cjs`
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/v1/build-agent.cjs`
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/v1/build-all.cjs`
- Test: `/Users/thomashulihan/Projects/gsd-codex/test/v1-generation.test.cjs`

- [ ] **Step 1: Write failing golden tests for a representative skill and agent**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const { buildSkillV1 } = require('../src/v1/build-skill.cjs');
const { buildAgentPairV1 } = require('../src/v1/build-agent.cjs');

test('buildSkillV1 emits a Codex adapter for gsd-do', () => {
  const skill = buildSkillV1({
    name: 'gsd-do',
    workflowPath: '/Users/thomashulihan/.codex/get-shit-done/workflows/do.md',
  });

  assert.match(skill, /<codex_skill_adapter>/);
  assert.match(skill, /@\$\HOME\/\.codex\/get-shit-done\/workflows\/do\.md/);
  assert.match(skill, /Route freeform text to the right GSD command automatically/);
});

test('buildAgentPairV1 emits matching markdown and toml for gsd-planner', () => {
  const pair = buildAgentPairV1({
    name: 'gsd-planner',
    markdownPath: '/Users/thomashulihan/.codex/agents/gsd-planner.md',
    tomlPath: '/Users/thomashulihan/.codex/agents/gsd-planner.toml',
  });

  assert.match(pair.markdown, /<codex_agent_role>/);
  assert.match(pair.toml, /name = "gsd-planner"/);
  assert.match(pair.toml, /sandbox_mode = "workspace-write"/);
});
```

- [ ] **Step 2: Run the generator tests to confirm the build layer is missing**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/v1-generation.test.cjs`

Expected: FAIL with missing module errors for `build-skill.cjs` and `build-agent.cjs`.

- [ ] **Step 3: Implement the `v1` generators**

```js
const fs = require('fs');

function buildSkillV1({ name, workflowPath }) {
  const workflow = fs.readFileSync(workflowPath, 'utf8').trim();
  const summary = name === 'gsd-do'
    ? 'Route freeform text to the right GSD command automatically'
    : `Codex adapter for ${name}`;

  return `---
name: "${name}"
description: "${summary}"
metadata:
  short-description: "${summary}"
---

<codex_skill_adapter>
## A. Skill Invocation
- This skill is invoked by mentioning $${name}.
- Treat all user text after $${name} as {{GSD_ARGS}}.
</codex_skill_adapter>

<execution_context>
@$HOME/.codex/get-shit-done/workflows/${workflowPath.split('/').pop()}
</execution_context>

<process>
${workflow}
</process>
`;
}

module.exports = { buildSkillV1 };
```

```js
const fs = require('fs');

function buildAgentPairV1({ name, markdownPath, tomlPath }) {
  return {
    markdown: fs.readFileSync(markdownPath, 'utf8'),
    toml: fs.readFileSync(tomlPath, 'utf8'),
  };
}

module.exports = { buildAgentPairV1 };
```

```js
const fs = require('fs');
const path = require('path');
const { scanInstalledGsd } = require('../catalog/installed-scan.cjs');
const { buildSkillV1 } = require('./build-skill.cjs');
const { buildAgentPairV1 } = require('./build-agent.cjs');

function buildAllV1({ codexHome, outputRoot }) {
  const catalog = scanInstalledGsd({ codexHome });
  fs.mkdirSync(path.join(outputRoot, 'skills'), { recursive: true });
  fs.mkdirSync(path.join(outputRoot, 'agents'), { recursive: true });

  for (const skillName of catalog.skills) {
    const workflowName = `${skillName.replace(/^gsd-/, '')}.md`;
    const skill = buildSkillV1({
      name: skillName,
      workflowPath: path.join(codexHome, 'get-shit-done', 'workflows', workflowName),
    });
    fs.mkdirSync(path.join(outputRoot, 'skills', skillName), { recursive: true });
    fs.writeFileSync(path.join(outputRoot, 'skills', skillName, 'SKILL.md'), skill);
  }

  for (const agentName of catalog.agents) {
    const pair = buildAgentPairV1({
      name: agentName,
      markdownPath: path.join(codexHome, 'agents', `${agentName}.md`),
      tomlPath: path.join(codexHome, 'agents', `${agentName}.toml`),
    });
    fs.writeFileSync(path.join(outputRoot, 'agents', `${agentName}.md`), pair.markdown);
    fs.writeFileSync(path.join(outputRoot, 'agents', `${agentName}.toml`), pair.toml);
  }
}

module.exports = { buildAllV1 };
```

- [ ] **Step 4: Run the tests and generate the `v1` dist tree**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/v1-generation.test.cjs && node -e "require('./src/v1/build-all.cjs').buildAllV1({ codexHome: '/Users/thomashulihan/.codex', outputRoot: './dist/v1' })"`

Expected: PASS, then `dist/v1/skills/gsd-do/SKILL.md` and `dist/v1/agents/gsd-planner.toml` exist.

- [ ] **Step 5: Commit the compatibility generator**

```bash
cd /Users/thomashulihan/Projects/gsd-codex
git add src/v1/build-skill.cjs src/v1/build-agent.cjs src/v1/build-all.cjs test/v1-generation.test.cjs
git commit -m "feat: generate gsd v1 codex compatibility track"
```

### Task 4: Add Track Selection and Install Sync

**Files:**
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/catalog/tracks.cjs`
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/install/write-manifest.cjs`
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/install/sync-to-codex.cjs`
- Test: `/Users/thomashulihan/Projects/gsd-codex/test/install-sync.test.cjs`

- [ ] **Step 1: Write the failing install-sync test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { syncTrackToCodex } = require('../src/install/sync-to-codex.cjs');

test('syncTrackToCodex installs the selected track and writes gsd-file-manifest.json', () => {
  const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), 'gsd-codex-'));

  syncTrackToCodex({
    projectRoot: '/Users/thomashulihan/Projects/gsd-codex',
    codexHome: tempHome,
    track: 'v1',
  });

  assert.ok(fs.existsSync(path.join(tempHome, 'skills', 'gsd-do', 'SKILL.md')));
  assert.ok(fs.existsSync(path.join(tempHome, 'agents', 'gsd-planner.toml')));
  assert.ok(fs.existsSync(path.join(tempHome, 'gsd-file-manifest.json')));
});
```

- [ ] **Step 2: Run the test to verify the install layer does not exist yet**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/install-sync.test.cjs`

Expected: FAIL with `Cannot find module '../src/install/sync-to-codex.cjs'`.

- [ ] **Step 3: Implement track selection and sync**

```js
function getTrackBuildRoot({ projectRoot, track }) {
  return `${projectRoot}/dist/${track}`;
}

module.exports = {
  TRACKS: ['v1', 'v2'],
  getTrackBuildRoot,
};
```

```js
const fs = require('fs');
const path = require('path');

function collectFiles(root, prefix = '') {
  const out = {};
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    const nextPrefix = prefix ? path.join(prefix, entry.name) : entry.name;
    const full = path.join(root, entry.name);
    if (entry.isDirectory()) {
      Object.assign(out, collectFiles(full, nextPrefix));
    } else {
      out[nextPrefix.replace(/\\/g, '/')] = fs.readFileSync(full, 'utf8').length;
    }
  }
  return out;
}

function writeManifest({ codexHome, track, version = 'codex-dev', sourceRoot }) {
  const payload = {
    version,
    track,
    timestamp: new Date().toISOString(),
    files: collectFiles(sourceRoot),
  };
  fs.writeFileSync(path.join(codexHome, 'gsd-file-manifest.json'), JSON.stringify(payload, null, 2));
}

module.exports = { writeManifest };
```

```js
const fs = require('fs');
const path = require('path');
const { getTrackBuildRoot } = require('../catalog/tracks.cjs');
const { writeManifest } = require('./write-manifest.cjs');

function copyTree(sourceRoot, targetRoot) {
  fs.mkdirSync(targetRoot, { recursive: true });
  for (const entry of fs.readdirSync(sourceRoot, { withFileTypes: true })) {
    const from = path.join(sourceRoot, entry.name);
    const to = path.join(targetRoot, entry.name);
    if (entry.isDirectory()) {
      copyTree(from, to);
    } else {
      fs.mkdirSync(path.dirname(to), { recursive: true });
      fs.copyFileSync(from, to);
    }
  }
}

function syncTrackToCodex({ projectRoot, codexHome, track }) {
  const buildRoot = getTrackBuildRoot({ projectRoot, track });
  copyTree(path.join(buildRoot, 'skills'), path.join(codexHome, 'skills'));
  copyTree(path.join(buildRoot, 'agents'), path.join(codexHome, 'agents'));
  writeManifest({ codexHome, track, sourceRoot: buildRoot });
}

module.exports = { syncTrackToCodex };
```

- [ ] **Step 4: Run the sync test and verify files landed in a temp Codex home**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/install-sync.test.cjs`

Expected: PASS, with a temp directory containing `skills/`, `agents/`, and `gsd-file-manifest.json`.

- [ ] **Step 5: Commit the install layer**

```bash
cd /Users/thomashulihan/Projects/gsd-codex
git add src/catalog/tracks.cjs src/install/write-manifest.cjs src/install/sync-to-codex.cjs test/install-sync.test.cjs
git commit -m "feat: add track-aware codex install sync"
```

### Task 5: Add the `v2` Native Rendering Pipeline

**Files:**
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/v2/render-skill.cjs`
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/v2/render-agent.cjs`
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/v2/build-all.cjs`
- Test: `/Users/thomashulihan/Projects/gsd-codex/test/v2-rendering.test.cjs`

- [ ] **Step 1: Write the failing `v2` renderer test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const { renderSkillV2 } = require('../src/v2/render-skill.cjs');
const { renderAgentV2 } = require('../src/v2/render-agent.cjs');

test('renderSkillV2 emits a native Codex skill without the compatibility adapter block', () => {
  const text = renderSkillV2({
    name: 'gsd-do',
    description: 'Codex-native routing entrypoint',
    objective: 'Route natural language requests to the correct GSD command.',
    process: ['Parse intent.', 'Choose one route.', 'Dispatch the chosen command.'],
  });

  assert.doesNotMatch(text, /<codex_skill_adapter>/);
  assert.match(text, /Codex-native routing entrypoint/);
  assert.match(text, /<objective>/);
});

test('renderAgentV2 emits matching markdown and toml outputs', () => {
  const pair = renderAgentV2({
    name: 'gsd-planner',
    description: 'Codex-native planner',
    sandbox_mode: 'workspace-write',
    roleMarkdown: '<role>Build executable plans for Codex.</role>',
  });

  assert.match(pair.markdown, /<codex_agent_role>/);
  assert.match(pair.toml, /name = "gsd-planner"/);
  assert.match(pair.toml, /sandbox_mode = "workspace-write"/);
});
```

- [ ] **Step 2: Run the renderer test to confirm the `v2` emitters are missing**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/v2-rendering.test.cjs`

Expected: FAIL with missing module errors for `render-skill.cjs` and `render-agent.cjs`.

- [ ] **Step 3: Implement the `v2` renderers**

```js
function renderSkillV2({ name, description, objective, execution_context = [], context = '', process = [] }) {
  const executionBlock = execution_context.length
    ? `<execution_context>\n${execution_context.join('\n')}\n</execution_context>\n\n`
    : '';
  const contextBlock = context ? `<context>\n${context}\n</context>\n\n` : '';

  return `---
name: "${name}"
description: "${description}"
metadata:
  short-description: "${description}"
---

<objective>
${objective}
</objective>

${executionBlock}${contextBlock}<process>
${process.join('\n')}
</process>
`;
}

module.exports = { renderSkillV2 };
```

```js
function renderAgentV2({ name, description, sandbox_mode, roleMarkdown }) {
  return {
    markdown: `---
name: "${name}"
description: "${description}"
---

<codex_agent_role>
role: ${name}
purpose: ${description}
</codex_agent_role>

${roleMarkdown}
`,
    toml: `name = "${name}"
description = "${description}"
sandbox_mode = "${sandbox_mode}"
developer_instructions = '''
${roleMarkdown}
'''
`,
  };
}

module.exports = { renderAgentV2 };
```

```js
const fs = require('fs');
const path = require('path');
const { renderSkillV2 } = require('./render-skill.cjs');
const { renderAgentV2 } = require('./render-agent.cjs');
const { V2_SKILLS } = require('./skill-registry.cjs');
const { V2_AGENTS } = require('./agent-registry.cjs');

function buildAllV2({ outputRoot }) {
  fs.mkdirSync(path.join(outputRoot, 'skills'), { recursive: true });
  fs.mkdirSync(path.join(outputRoot, 'agents'), { recursive: true });

  for (const skill of V2_SKILLS) {
    const text = renderSkillV2(skill);
    fs.mkdirSync(path.join(outputRoot, 'skills', skill.name), { recursive: true });
    fs.writeFileSync(path.join(outputRoot, 'skills', skill.name, 'SKILL.md'), text);
  }

  for (const agent of V2_AGENTS) {
    const pair = renderAgentV2(agent);
    fs.writeFileSync(path.join(outputRoot, 'agents', `${agent.name}.md`), pair.markdown);
    fs.writeFileSync(path.join(outputRoot, 'agents', `${agent.name}.toml`), pair.toml);
  }
}

module.exports = { buildAllV2 };
```

- [ ] **Step 4: Run the renderer test**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/v2-rendering.test.cjs`

Expected: PASS, proving the renderers can emit installable `v2` artifacts.

- [ ] **Step 5: Commit the `v2` rendering base**

```bash
cd /Users/thomashulihan/Projects/gsd-codex
git add src/v2/render-skill.cjs src/v2/render-agent.cjs src/v2/build-all.cjs test/v2-rendering.test.cjs
git commit -m "feat: add v2 native codex renderers"
```

### Task 6: Author the `v2` Planning Track

**Files:**
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/v2/skill-registry.cjs`
- Create: `/Users/thomashulihan/Projects/gsd-codex/src/v2/agent-registry.cjs`
- Test: `/Users/thomashulihan/Projects/gsd-codex/test/v2-planning-track.test.cjs`

- [ ] **Step 1: Write the failing planning-track registry test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const { V2_SKILLS } = require('../src/v2/skill-registry.cjs');
const { V2_AGENTS } = require('../src/v2/agent-registry.cjs');

test('v2 planning track includes routing and plan orchestration skills', () => {
  const names = V2_SKILLS.map(item => item.name);
  assert.deepEqual(names.slice(0, 2), ['gsd-do', 'gsd-plan-phase']);
});

test('v2 planning track includes planner, researcher, and checker agents', () => {
  const names = V2_AGENTS.map(item => item.name);
  assert.ok(names.includes('gsd-phase-researcher'));
  assert.ok(names.includes('gsd-planner'));
  assert.ok(names.includes('gsd-plan-checker'));
});
```

- [ ] **Step 2: Run the test to confirm the registries are not authored yet**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/v2-planning-track.test.cjs`

Expected: FAIL with missing module errors for the registry files.

- [ ] **Step 3: Add `v2` skill registry entries for `gsd-do` and `gsd-plan-phase`**

```js
const V2_SKILLS = [
  {
    name: 'gsd-do',
    description: 'Codex-native routing entrypoint for GSD',
    objective: 'Route natural-language requests to exactly one GSD command without doing the work inline.',
    execution_context: [
      '@$HOME/.codex/get-shit-done/workflows/do.md'
    ],
    context: 'Project state is discovered at runtime from .planning/ when present.',
    process: [
      'Validate the user input is non-empty.',
      'Read project state via gsd-tools.cjs state load when .planning/ exists.',
      'Map the request to one command.',
      'Ask a clarifying question only when routing is ambiguous.',
      'Dispatch the selected command and stop.'
    ],
  },
  {
    name: 'gsd-plan-phase',
    description: 'Codex-native phase planner with research and checker loop',
    objective: 'Create executable phase plans by orchestrating context load, optional research, planning, and checker iteration.',
    execution_context: [
      '@$HOME/.codex/get-shit-done/workflows/plan-phase.md',
      '@$HOME/.codex/get-shit-done/references/ui-brand.md'
    ],
    context: 'Supports --research, --skip-research, --gaps, --skip-verify, --prd, --reviews, and --text.',
    process: [
      'Resolve the phase via gsd-tools.cjs init plan-phase.',
      'Load CONTEXT.md or generate it from --prd when present.',
      'Spawn gsd-phase-researcher when research is required.',
      'Spawn gsd-planner to produce plans.',
      'Spawn gsd-plan-checker and iterate until pass or max revisions.'
    ],
  },
];

module.exports = { V2_SKILLS };
```

- [ ] **Step 4: Add `v2` agent registry entries for the planning worker roles**

```js
const V2_AGENTS = [
  {
    name: 'gsd-phase-researcher',
    description: 'Researches implementation choices for a single phase using current docs and local project context.',
    sandbox_mode: 'workspace-write',
    roleMarkdown: `<role>
You are the Codex-native GSD phase researcher.
Read the files in <files_to_read> first.
Prefer official docs and local source over memory.
Write concise research artifacts that a planner can execute against.
</role>`,
  },
  {
    name: 'gsd-planner',
    description: 'Builds executable phase plans for Codex workers.',
    sandbox_mode: 'workspace-write',
    roleMarkdown: `<role>
You are the Codex-native GSD planner.
Honor locked decisions from CONTEXT.md.
Produce small, dependency-aware plans that fit Codex execution and review loops.
</role>`,
  },
  {
    name: 'gsd-plan-checker',
    description: 'Verifies phase plans are complete, structured, and executable.',
    sandbox_mode: 'workspace-write',
    roleMarkdown: `<role>
You are the Codex-native GSD plan checker.
Review plans for missing prerequisites, broken task ordering, weak verification, and missing user decisions.
</role>`,
  },
];

module.exports = { V2_AGENTS };
```

- [ ] **Step 5: Run the registry test and commit**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/v2-planning-track.test.cjs`

Expected: PASS, confirming the planning-side `v2` registry is declared.

```bash
cd /Users/thomashulihan/Projects/gsd-codex
git add src/v2/skill-registry.cjs src/v2/agent-registry.cjs test/v2-planning-track.test.cjs
git commit -m "feat: define v2 planning track registries"
```

### Task 7: Author the `v2` Execution Track

**Files:**
- Modify: `/Users/thomashulihan/Projects/gsd-codex/src/v2/skill-registry.cjs`
- Modify: `/Users/thomashulihan/Projects/gsd-codex/src/v2/agent-registry.cjs`
- Test: `/Users/thomashulihan/Projects/gsd-codex/test/v2-execution-track.test.cjs`

- [ ] **Step 1: Write the failing execution-track test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const { V2_SKILLS } = require('../src/v2/skill-registry.cjs');
const { V2_AGENTS } = require('../src/v2/agent-registry.cjs');

test('v2 execution track includes gsd-execute-phase and gsd-autonomous', () => {
  const names = V2_SKILLS.map(item => item.name);
  assert.ok(names.includes('gsd-execute-phase'));
  assert.ok(names.includes('gsd-autonomous'));
});

test('v2 execution track includes gsd-executor', () => {
  const names = V2_AGENTS.map(item => item.name);
  assert.ok(names.includes('gsd-executor'));
});
```

- [ ] **Step 2: Run the execution-track test before adding the entries**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/v2-execution-track.test.cjs`

Expected: FAIL because the `gsd-execute-phase`, `gsd-autonomous`, and `gsd-executor` entries do not exist yet.

- [ ] **Step 3: Extend the `v2` skill registry with execution orchestration**

```js
V2_SKILLS.push(
  {
    name: 'gsd-execute-phase',
    description: 'Codex-native phase executor with wave-aware subagent dispatch',
    execution_context: [
      '@$HOME/.codex/get-shit-done/workflows/execute-phase.md',
      '@$HOME/.codex/get-shit-done/references/checkpoints.md'
    ],
    objective: 'Execute incomplete plans in dependency order, using Codex subagents when appropriate and inline execution when checkpoints or runtime limits demand it.',
    context: 'Supports --wave, --gaps-only, and --interactive.',
    process: [
      'Resolve phase state from gsd-tools.cjs init execute-phase.',
      'Build the plan index and wave groups.',
      'Spawn gsd-executor per plan when parallel execution is safe.',
      'Fall back to inline execution when interactive mode is requested.',
      'Update STATE.md and hand off to phase verification when done.'
    ],
  },
  {
    name: 'gsd-autonomous',
    description: 'Codex-native milestone autopilot for discuss, plan, execute, and closeout',
    execution_context: [
      '@$HOME/.codex/get-shit-done/workflows/autonomous.md'
    ],
    objective: 'Run the remaining milestone phases end-to-end using the Codex-native planning and execution tracks.',
    context: 'Supports --from N to start from a later phase.',
    process: [
      'Discover remaining phases from ROADMAP.md.',
      'Run discuss only when context is missing.',
      'Invoke gsd-plan-phase for each incomplete phase.',
      'Invoke gsd-execute-phase for each planned phase.',
      'Finish with milestone audit, completion, and cleanup.'
    ],
  }
);
```

- [ ] **Step 4: Extend the agent registry with the executor role**

```js
V2_AGENTS.push({
  name: 'gsd-executor',
  description: 'Executes a single PLAN.md with Codex-native checkpoint and deviation handling.',
  sandbox_mode: 'workspace-write',
  roleMarkdown: `<role>
You are the Codex-native GSD executor.
Read every file in <files_to_read> before acting.
Execute one plan completely, commit task-sized changes, record deviations, and stop at explicit checkpoints.
</role>

<rules>
- Fix correctness and blocking issues inline when they are inside task scope.
- Escalate only architectural changes or authentication gates.
- Keep execution bounded to the active plan and touched files.
</rules>`,
});
```

- [ ] **Step 5: Run the test, build `v2`, and commit**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/v2-execution-track.test.cjs && node -e "require('./src/v2/build-all.cjs').buildAllV2({ outputRoot: './dist/v2' })"`

Expected: PASS, then `dist/v2/skills/gsd-execute-phase/SKILL.md`, `dist/v2/skills/gsd-autonomous/SKILL.md`, and `dist/v2/agents/gsd-executor.toml` exist.

```bash
cd /Users/thomashulihan/Projects/gsd-codex
git add src/v2/skill-registry.cjs src/v2/agent-registry.cjs test/v2-execution-track.test.cjs
git commit -m "feat: define v2 execution track registries"
```

### Task 8: Add Smoke Validation, Rollout Docs, and Real Install Commands

**Files:**
- Create: `/Users/thomashulihan/Projects/gsd-codex/test/smoke-install.test.cjs`
- Create: `/Users/thomashulihan/Projects/gsd-codex/docs/rollout.md`
- Modify: `/Users/thomashulihan/Projects/gsd-codex/README.md`

- [ ] **Step 1: Write the failing smoke-install test**

```js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { buildAllV1 } = require('../src/v1/build-all.cjs');
const { buildAllV2 } = require('../src/v2/build-all.cjs');
const { syncTrackToCodex } = require('../src/install/sync-to-codex.cjs');

test('both tracks can build and install into isolated Codex homes', () => {
  const projectRoot = '/Users/thomashulihan/Projects/gsd-codex';
  const codexHomeV1 = fs.mkdtempSync(path.join(os.tmpdir(), 'gsd-v1-'));
  const codexHomeV2 = fs.mkdtempSync(path.join(os.tmpdir(), 'gsd-v2-'));

  buildAllV1({ codexHome: '/Users/thomashulihan/.codex', outputRoot: path.join(projectRoot, 'dist', 'v1') });
  buildAllV2({ outputRoot: path.join(projectRoot, 'dist', 'v2') });

  syncTrackToCodex({ projectRoot, codexHome: codexHomeV1, track: 'v1' });
  syncTrackToCodex({ projectRoot, codexHome: codexHomeV2, track: 'v2' });

  assert.ok(fs.existsSync(path.join(codexHomeV1, 'skills', 'gsd-do', 'SKILL.md')));
  assert.ok(fs.existsSync(path.join(codexHomeV2, 'skills', 'gsd-execute-phase', 'SKILL.md')));
});
```

- [ ] **Step 2: Run the smoke test before adding docs and final wiring**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && node --test test/smoke-install.test.cjs`

Expected: FAIL until all previous tasks are complete and the project can fully build both tracks.

- [ ] **Step 3: Document the local workflow and rollout**

```md
# Rollout

## Build `v1`

- `cd /Users/thomashulihan/Projects/gsd-codex`
- `npm run build:v1`
- `npm run sync:v1`

## Build `v2`

- `cd /Users/thomashulihan/Projects/gsd-codex`
- `npm run build:v2`
- `npm run sync:v2`

## Validate

- `cd /Users/thomashulihan/Projects/gsd-codex`
- `npm test`
- `cat /Users/thomashulihan/.codex/gsd-file-manifest.json`

## Roll back

Reinstall the previous track with the matching `npm run sync:v1` or `npm run sync:v2` command.
```

```md
# gsd-codex

## Commands

- `npm test` — run all unit and smoke coverage
- `npm run build:v1` — generate compatibility artifacts
- `npm run build:v2` — generate native Codex artifacts
- `npm run sync:v1` — install compatibility artifacts into `~/.codex`
- `npm run sync:v2` — install native Codex artifacts into `~/.codex`
```

- [ ] **Step 4: Run the full test suite and one real dry-run install**

Run: `cd /Users/thomashulihan/Projects/gsd-codex && npm test && node -e "require('./src/install/sync-to-codex.cjs').syncTrackToCodex({ projectRoot: process.cwd(), codexHome: '/tmp/gsd-codex-dry-run', track: 'v2' })"`

Expected: PASS, then `/tmp/gsd-codex-dry-run/skills/` and `/tmp/gsd-codex-dry-run/agents/` exist with a new manifest file.

- [ ] **Step 5: Commit the rollout layer**

```bash
cd /Users/thomashulihan/Projects/gsd-codex
git add README.md docs/rollout.md test/smoke-install.test.cjs
git commit -m "docs: add codex gsd rollout and smoke validation"
```
