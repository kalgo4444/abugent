// Root entrypoint for OpenCode V2 directory-form plugin registration, e.g.
// `"plugins": ["/path/to/abugent"]` (`~` is not expanded). V2 requires the
// directory to contain an `index.js`; npm/git installs use package.json `main`.
export { default, AbugentPlugin } from "./.opencode/plugins/abugent.js";
