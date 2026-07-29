// Admin pack.
//
// The election list is server-rendered and needs nothing from here. The
// one-page editor does: adding a question or an option without a page load is
// the whole point of it, and the draft autosave and the leave confirmation
// come with it. The census needs the same treatment for its rows,
// plus the live security meter. The monitoring page needs a refresh control
// that visibly does something, and the publication page needs its button
// locked until both confirmations are given.
import "stylesheets/decidim/secure_elections/admin/editor.scss";
import "src/decidim/secure_elections/admin/election_editor";
import "src/decidim/secure_elections/admin/census";
import "src/decidim/secure_elections/admin/public_link";
import "src/decidim/secure_elections/admin/monitor";
import "src/decidim/secure_elections/admin/setup";
