--!strict

local Packages = script.Parent.Parent.Parent.Parent.packages
local Fusion = require(Packages.fusion)

local Computed = Fusion.Computed

local function ComputeUDim(
    scope: Fusion.Scope,
    scale: Fusion.UsedAs<number>,
    offset: Fusion.UsedAs<number>
)
    return scope:Computed(function(use, scope)
        return UDim.new(use(scale), use(offset))
    end)
end

local function ComputeUDim2(
    scope: Fusion.Scope<typeof(Fusion)>,
    width: Fusion.UsedAs<UDim>,
    height: Fusion.UsedAs<UDim>
)
    return Computed(scope, function(use, scope)
        local usedWidth, usedHeight = use<<UDim>>(width), use<<UDim>>(height)

        return UDim2.new(
            usedWidth.Scale, usedWidth.Offset,
            usedHeight.Scale, usedHeight.Offset
        )
    end)
end

local function ComputeUDim2FromScale(
    scope: Fusion.Scope<typeof(Fusion)>,
    scaleWidth: Fusion.UsedAs<number>,
    scaleHeight: Fusion.UsedAs<number>
)
    return Computed(scope, function(use, scope)
        local usedScaleWidth, usedScaleHeight =
            use<<number>>(scaleWidth), use<<number>>(scaleHeight)

        return UDim2.fromScale(usedScaleWidth, usedScaleHeight)
    end)
end

local function ComputeUDim2FromOffset(
    scope: Fusion.Scope,
    offsetWidth: Fusion.UsedAs<number>,
    offsetHeight: Fusion.UsedAs<number>
)
    return Computed(scope, function(use, scope)
        local usedScaleWidth, usedScaleHeight =
            use<<number>>(offsetWidth), use<<number>>(offsetHeight)

        return UDim2.fromOffset(usedScaleWidth, usedScaleHeight)
    end)
end


local function ComputeTweenInfo(
  scope: Fusion.Scope,
  time: Fusion.UsedAs<number>,
  easingStyle: Fusion.UsedAs<Enum.EasingStyle>?,
  easingDirection: Fusion.UsedAs<Enum.EasingDirection>?,
  repeatCount: Fusion.UsedAs<number>?,
  reverses: Fusion.UsedAs<number>?,
  delayTime: Fusion.UsedAs<number>?
)
    return Computed(scope, function(use, scope)
        return TweenInfo.new(
            use<<number>>(time),
            use<<any>>(easingStyle) or Enum.EasingStyle.Linear,
            use<<any>>(easingDirection) or Enum.EasingDirection.In,
            use<<any>>(repeatCount) or 0,
            use<<any>>(reverses) or false,
            use<<any>>(delayTime) or 0
        )
    end)
end

return {
  UDim = ComputeUDim,

  UDim2 = ComputeUDim2,
  UDim2FromScale = ComputeUDim2FromScale,
  UDim2FromOffset = ComputeUDim2FromOffset,

  TweenInfo = ComputeTweenInfo
}
