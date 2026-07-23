--!strict

export type Placement = {
    Position: UDim2,
    AnchorPoint: Vector2
}

export type FitProps = {
    PreferredPosition: UDim2,
    PreferredAnchorPoint: Vector2,
    ParentPosition: Vector2,
    ParentSize: Vector2,
    MenuSize: Vector2,
    ViewportPosition: Vector2,
    ViewportSize: Vector2,
    PositionOffsetScale: number?
}

type FlipCandidate = {
    X: boolean,
    Y: boolean
}

local FlipCandidates: { FlipCandidate } = {
    { X = false, Y = false },
    { X = false, Y = true },
    { X = true, Y = false },
    { X = true, Y = true }
}

local function MirrorUDim(value: UDim): UDim
    return UDim.new(1 - value.Scale, -value.Offset)
end

local function GetCandidate(
    preferredPosition: UDim2,
    preferredAnchorPoint: Vector2,
    flip: FlipCandidate
): Placement
    return {
        Position = UDim2.new(
            if flip.X then MirrorUDim(preferredPosition.X)
            else preferredPosition.X,
            if flip.Y then MirrorUDim(preferredPosition.Y)
            else preferredPosition.Y
        ),
        AnchorPoint = Vector2.new(
            if flip.X then 1 - preferredAnchorPoint.X
            else preferredAnchorPoint.X,
            if flip.Y then 1 - preferredAnchorPoint.Y
            else preferredAnchorPoint.Y
        )
    }
end

local function ResolveTopLeft(
    placement: Placement,
    parentPosition: Vector2,
    parentSize: Vector2,
    menuSize: Vector2,
    positionOffsetScale: number
): Vector2
    local position = placement.Position
    local anchorPoint = placement.AnchorPoint
    local attachmentPoint = parentPosition + Vector2.new(
        parentSize.X * position.X.Scale
            + position.X.Offset * positionOffsetScale,
        parentSize.Y * position.Y.Scale
            + position.Y.Offset * positionOffsetScale
    )

    return attachmentPoint - Vector2.new(
        menuSize.X * anchorPoint.X,
        menuSize.Y * anchorPoint.Y
    )
end

local function FitAxis(
    menuStart: number,
    menuSize: number,
    viewportStart: number,
    viewportEnd: number
): number
    local endAlignedStart = viewportEnd - menuSize

    return math.clamp(
        menuStart,
        math.min(viewportStart, endAlignedStart),
        math.max(viewportStart, endAlignedStart)
    )
end

local function GetCorrection(
    menuPosition: Vector2,
    menuSize: Vector2,
    viewportPosition: Vector2,
    viewportSize: Vector2
): Vector2
    local viewportEnd = viewportPosition + viewportSize
    local fittedPosition = Vector2.new(
        FitAxis(
            menuPosition.X,
            menuSize.X,
            viewportPosition.X,
            viewportEnd.X
        ),
        FitAxis(
            menuPosition.Y,
            menuSize.Y,
            viewportPosition.Y,
            viewportEnd.Y
        )
    )

    return fittedPosition - menuPosition
end

local function GetCorrectionScore(correction: Vector2): number
    return correction.X * correction.X + correction.Y * correction.Y
end

local function Fit(props: FitProps): Placement
    local positionOffsetScale = props.PositionOffsetScale or 1
    if positionOffsetScale <= 0 then positionOffsetScale = 1 end

    local firstFlip = FlipCandidates[1]
    local bestPlacement = GetCandidate(
        props.PreferredPosition,
        props.PreferredAnchorPoint,
        firstFlip
    )
    local bestCorrection = GetCorrection(
        ResolveTopLeft(
            bestPlacement,
            props.ParentPosition,
            props.ParentSize,
            props.MenuSize,
            positionOffsetScale
        ),
        props.MenuSize,
        props.ViewportPosition,
        props.ViewportSize
    )
    local bestScore = GetCorrectionScore(bestCorrection)

    for idx = 2, #FlipCandidates do
        local placement = GetCandidate(
            props.PreferredPosition,
            props.PreferredAnchorPoint,
            FlipCandidates[idx]
        )
        local correction = GetCorrection(
            ResolveTopLeft(
                placement,
                props.ParentPosition,
                props.ParentSize,
                props.MenuSize,
                positionOffsetScale
            ),
            props.MenuSize,
            props.ViewportPosition,
            props.ViewportSize
        )
        local score = GetCorrectionScore(correction)

        if score >= bestScore then continue end

        bestPlacement = placement
        bestCorrection = correction
        bestScore = score
    end

    local position = bestPlacement.Position
    local offsetCorrection = bestCorrection / positionOffsetScale

    return {
        Position = UDim2.new(
            position.X.Scale,
            position.X.Offset + offsetCorrection.X,
            position.Y.Scale,
            position.Y.Offset + offsetCorrection.Y
        ),
        AnchorPoint = bestPlacement.AnchorPoint
    }
end

return {
    Fit = Fit
}
