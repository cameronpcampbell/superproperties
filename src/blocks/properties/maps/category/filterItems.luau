--!strict

type Item = { Key: string, Value: any }

type Candidate = {
    Compact: string,
    BoundaryCharacters: string,
    BoundaryBonuses: { number }
}

type ScoredItem = {
    Item: Item,
    Score: number,
    Index: number
}

local ExactScore = 1_000_000
local PrefixScore = 900_000
local BoundaryScore = 850_000
local SubstringScore = 800_000
local SubsequenceScore = 700_000

local BoundaryBonus = 20
local ConsecutiveBonus = 10
local GapPenalty = 1
local MinLooseMatchLength = 3

local function IsWhitespace(character: string): boolean
    return character:match("%s") ~= nil
end

local function IsBoundary(
    character: string,
    previousCharacter: string?,
    compactLength: number
): boolean
    if compactLength == 0 or not previousCharacter then return true end

    if previousCharacter:match("[%w]") == nil then return true end

    return
        previousCharacter:match("%l") ~= nil and
        character:match("%u") ~= nil
end

local function PrepareCandidate(input: string): Candidate
    local compactCharacters = {}
    local boundaryCharacters = {}
    local boundaryBonuses = {}
    local previousCharacter: string? = nil

    for idx = 1, #input do
        local character = input:sub(idx, idx)

        if not IsWhitespace(character) then
            local compactIdx = #compactCharacters + 1
            local isBoundary =
                IsBoundary(character, previousCharacter, #compactCharacters)

            compactCharacters[compactIdx] = character:lower()
            boundaryBonuses[compactIdx] = if isBoundary then BoundaryBonus else 0

            if isBoundary then
                table.insert(boundaryCharacters, character:lower())
            end
        end

        previousCharacter = character
    end

    return {
        Compact = table.concat(compactCharacters),
        BoundaryCharacters = table.concat(boundaryCharacters),
        BoundaryBonuses = boundaryBonuses
    }
end

local function NormalizeQuery(query: string?): string
    if not query then return "" end

    local normalizedQuery = query:lower():gsub("%s+", "")
    return normalizedQuery
end

-- Scores an ordered subsequence in O(query length * candidate length).
-- Consecutive and word-boundary matches are preferred while gaps are penalised.
local function ScoreSubsequence(
    candidate: Candidate,
    query: string
): number?
    local candidateText = candidate.Compact
    local candidateLength = #candidateText
    local queryLength = #query

    if queryLength > candidateLength then return nil end

    local previousScores = table.create(candidateLength, -math.huge)

    local firstQueryCharacter = query:sub(1, 1)
    for candidateIdx = 1, candidateLength do
        if candidateText:sub(candidateIdx, candidateIdx) == firstQueryCharacter then
            previousScores[candidateIdx] =
                candidate.BoundaryBonuses[candidateIdx] -
                (candidateIdx - 1) * GapPenalty
        end
    end

    for queryIdx = 2, queryLength do
        local scores = table.create(candidateLength, -math.huge)
        local queryCharacter = query:sub(queryIdx, queryIdx)
        local bestGapScore = -math.huge

        for candidateIdx = 1, candidateLength do
            local previousGapIdx = candidateIdx - 2
            if previousGapIdx >= 1 then
                bestGapScore = math.max(
                    bestGapScore,
                    previousScores[previousGapIdx] +
                        previousGapIdx * GapPenalty
                )
            end

            if candidateText:sub(candidateIdx, candidateIdx) ~= queryCharacter then
                continue
            end

            local bestScore = -math.huge

            if candidateIdx > 1 then
                bestScore =
                    previousScores[candidateIdx - 1] + ConsecutiveBonus
            end

            if bestGapScore > -math.huge then
                bestScore = math.max(
                    bestScore,
                    bestGapScore - (candidateIdx - 1) * GapPenalty
                )
            end

            if bestScore > -math.huge then
                scores[candidateIdx] =
                    bestScore + candidate.BoundaryBonuses[candidateIdx]
            end
        end

        previousScores = scores
    end

    local bestScore = -math.huge
    for candidateIdx = 1, candidateLength do
        local score = previousScores[candidateIdx]

        if score > -math.huge then
            score -= (candidateLength - candidateIdx) * GapPenalty
            bestScore = math.max(bestScore, score)
        end
    end

    return if bestScore > -math.huge then bestScore else nil
end

local function ScoreCandidate(candidate: Candidate, query: string): number?
    local candidateText = candidate.Compact
    local lengthPenalty = #candidateText - #query
    local isShortWordQuery =
        #query < MinLooseMatchLength and query:match("^%w+$") ~= nil

    if candidateText == query then
        return ExactScore
    end

    if candidateText:sub(1, #query) == query then
        return PrefixScore - lengthPenalty
    end

    if candidate.BoundaryCharacters:sub(1, #query) == query then
        return BoundaryScore - lengthPenalty
    end

    local substringStart = candidateText:find(query, 1, true)
    while substringStart do
        if
            not isShortWordQuery or
            candidate.BoundaryBonuses[substringStart] > 0
        then
            return
                SubstringScore -
                (substringStart - 1) * 100 -
                lengthPenalty
        end

        substringStart = candidateText:find(query, substringStart + 1, true)
    end

    -- Very short fuzzy matches are usually noise. They still match prefixes,
    -- camel-case initials, and boundary substrings through the tiers above.
    if isShortWordQuery then return nil end

    local subsequence = ScoreSubsequence(candidate, query)
    if not subsequence then return nil end

    return SubsequenceScore + subsequence * 10 - lengthPenalty
end

local function FilterItems(items: { Item }, query: string?): { Item }
    local normalizedQuery = NormalizeQuery(query)
    if normalizedQuery == "" then return table.clone(items) end

    local scoredItems: { ScoredItem } = {}

    for idx, item in items do
        local score = ScoreCandidate(PrepareCandidate(item.Key), normalizedQuery)
        if not score then continue end

        table.insert(scoredItems, {
            Item = item,
            Score = score,
            Index = idx
        })
    end

    table.sort(scoredItems, function(a: ScoredItem, b: ScoredItem): boolean
        if a.Score ~= b.Score then return a.Score > b.Score end

        local lowerKeyA = a.Item.Key:lower()
        local lowerKeyB = b.Item.Key:lower()

        if lowerKeyA ~= lowerKeyB then return lowerKeyA < lowerKeyB end
        if a.Item.Key ~= b.Item.Key then return a.Item.Key < b.Item.Key end

        return a.Index < b.Index
    end)

    local filteredItems: { Item } = {}
    for idx, scoredItem in scoredItems do
        filteredItems[idx] = scoredItem.Item
    end

    return filteredItems
end

return FilterItems
