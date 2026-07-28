# v0.3.0
- Properties, attributes, and tags can now be bookmarked.
- Fixed resource leaks during failed initialization and plugin unload, preventing orphaned widgets, Instances, and event connections.
- Properties with numbers now support math expressions.
- Fixed issue where nested properties would obscure the focus ring of their direct parent.

# v0.2.0
- Properties that are not accessible to the plugin are now displayed, but they are highlighted with the caution foreground color.
- Disabled buttons and checkboxes now show the `NotAllowed` cursor, instead of `PointingHand`.
- Scrollbar underlay color is slightly darker to improve contrast.
- Map headers can now be tinted with a random color.
- Non Scriptable properties can now be hidden.
- Instance component now refetches class icons when studio theme changes.

# v0.1.0
- Initial release.
