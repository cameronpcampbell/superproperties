--!strict

local Packages = script.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Mosaic = require(Packages.mosaic)
local BooleanIconButton, Input, Icon =
    Mosaic.BooleanIconButton, Mosaic.Input, Mosaic.Icon

local Assets = require(script.Parent.Parent.Parent.assets)
local GetBookmarkButtonVisualState =
    require(script.Parent.getBookmarkButtonVisualState)
local GetBookmarksOnlyState = require(script.Parent.getBookmarksOnlyState)
local GetFilterState = require(script.Parent.getFilterState)

return function(scope: Fusion.Scope)
    local bookmarksOnlyState = GetBookmarksOnlyState(scope)
    local bookmarkButtonVisualState =
        GetBookmarkButtonVisualState(scope)
    local filterState = GetFilterState(scope)

    return Input(scope, {
        PlaceholderText = "Filter Properties",
        Text = filterState,

        LeftChildren = Icon(scope, {
            Image = Assets.Search,
        }),
        RightChildren = BooleanIconButton(scope, {
            Value = bookmarkButtonVisualState,
            TruthyIcon = Assets.BookmarkFill,
            FalseyIcon = Assets.BookmarkOutlineThin,

            OnChanged = function(bookmarksOnly: boolean)
                bookmarksOnlyState:set(bookmarksOnly)
            end,

            Name = "BookmarkButton"
        })
    })
end
