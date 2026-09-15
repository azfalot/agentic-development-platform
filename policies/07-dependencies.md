# GLOBAL DEVELOPMENT POLICY — THIRD-PARTY DEPENDENCIES

This policy defines the evaluation protocol before adding new libraries or dependencies to any project.

---

## 1. PRE-INSTALLATION CHECKLIST

Before running `npm install`, `pnpm add`, `pip install`, `cargo add`, or adding Maven/Gradle dependencies, the agent must verify:
1. **Existing Code:** Does the codebase already contain a utility or function that solves this problem?
2. **Framework Capabilities:** Does the underlying framework (Spring Boot, Node standard library, React, FastAPI, etc.) natively support this without extra packages?
3. **Maintenance & Popularity:** Is the package actively maintained, well-tested, and widely adopted?
4. **License & Security:** Does the package have known CVEs or an incompatible license (e.g. AGPL in commercial contexts)?

---

## 2. PROHIBITION OF CASUAL DEPENDENCIES

* Agents must **not** introduce heavy libraries (e.g. Lodash, Moment.js, Axios, Apache Commons) for trivial operations that require only a few lines of standard modern language code.
* Justify any non-trivial runtime dependency in the PR description.
