// Jest for this module's packs. `app/packs` is registered as a module
// directory so the sources can use the same absolute `src/decidim/...` imports
// that Shakapacker resolves at build time.
module.exports = {
  rootDir: __dirname,
  testEnvironment: "jsdom",
  testEnvironmentOptions: { url: "https://decidim.dev/" },
  moduleFileExtensions: ["js"],
  moduleDirectories: ["node_modules", "<rootDir>/app/packs"],
  moduleNameMapper: { "\\.(scss|css|less)$": "identity-obj-proxy" },
  setupFiles: ["<rootDir>/jest.setup.js"],
  transform: { "\\.js$": "babel-jest" },
  testRegex: "\\.(test|spec)\\.js$"
};
