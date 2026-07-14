--!strict
--!native

type Item = { Key: string, Value: any }

type PreparedQuery = {
    Text: string,
    Bytes: { number },
    Length: number,
    IsShortWord: boolean
}

type Candidate = {
    LowerKey: string,
    Compact: string,
    CompactBytes: { number },
    BoundaryCharacters: string,
    BoundaryBonuses: { number }
}

type PreparedItem = {
    Item: Item,
    Key: string,
    Candidate: Candidate,
    LowerKey: string,
    Idx: number
}

type ScoredItem = {
    PreparedItem: PreparedItem,
    Score: number
}

type ItemFilter = (query: string?) -> { Item }

local ExactScore = 1_000_000
local PrefixScore = 900_000
local BoundaryScore = 850_000
local SubstringScore = 800_000
local SubsequenceScore = 700_000

local BoundaryBonus = 20
local ConsecutiveBonus = 10
local GapPenalty = 1
local MinLooseMatchLength = 3
local NegativeInfinity = -math.huge

local CandidateCache: { [string]: Candidate } = {}

local function IsWhitespaceByte(byte: number): boolean
    return byte == 32 or byte >= 9 and byte <= 13
end

local function IsLowercaseByte(byte: number): boolean
    return byte >= 97 and byte <= 122
end

local function IsUppercaseByte(byte: number): boolean
    return byte >= 65 and byte <= 90
end

local function IsWordByte(byte: number): boolean
    return
        byte >= 48 and byte <= 57 or
        IsUppercaseByte(byte) or
        IsLowercaseByte(byte)
end

local function IsBoundaryByte(
    byte: number,
    previousByte: number?,
    compactLength: number
): boolean
    if compactLength == 0 or not previousByte then return true end
    if not IsWordByte(previousByte) then return true end

    return IsLowercaseByte(previousByte) and IsUppercaseByte(byte)
end

local function PrepareCandidate(input: string): Candidate
    local inputLength = #input
    local lowerInput = input:lower()
    local compactCharacters = table.create(inputLength) :: { string }
    local compactBytes = table.create(inputLength) :: { number }
    local boundaryCharacters = table.create(inputLength) :: { string }
    local boundaryBonuses = table.create(inputLength) :: { number }
    local compactLength = 0
    local boundaryLength = 0
    local previousByte: number? = nil

    for idx = 1, inputLength do
        local byte = input:byte(idx)

        if not IsWhitespaceByte(byte) then
            compactLength += 1

            local lowerCharacter = lowerInput:sub(idx, idx)
            local isBoundary =
                IsBoundaryByte(byte, previousByte, compactLength - 1)

            compactCharacters[compactLength] = lowerCharacter
            compactBytes[compactLength] = lowerInput:byte(idx)
            boundaryBonuses[compactLength] =
                if isBoundary then BoundaryBonus else 0

            if isBoundary then
                boundaryLength += 1
                boundaryCharacters[boundaryLength] = lowerCharacter
            end
        end

        previousByte = byte
    end

    return {
        LowerKey = lowerInput,
        Compact = table.concat(compactCharacters),
        CompactBytes = compactBytes,
        BoundaryCharacters = table.concat(boundaryCharacters),
        BoundaryBonuses = boundaryBonuses
    }
end

local function GetCandidate(key: string): Candidate
    local candidate = CandidateCache[key]
    if candidate then return candidate end

    local preparedCandidate = PrepareCandidate(key)
    CandidateCache[key] = preparedCandidate
    return preparedCandidate
end

local function PrepareItem(item: Item, itemIdx: number): PreparedItem
    local key = item.Key
    local candidate = GetCandidate(key)

    return {
        Item = item,
        Key = key,
        Candidate = candidate,
        LowerKey = candidate.LowerKey,
        Idx = itemIdx
    }
end

local function RefreshPreparedItem(preparedItem: PreparedItem)
    local key = preparedItem.Item.Key
    if preparedItem.Key == key then return end

    local candidate = GetCandidate(key)
    preparedItem.Key = key
    preparedItem.Candidate = candidate
    preparedItem.LowerKey = candidate.LowerKey
end

local function PrepareQuery(query: string?): PreparedQuery
    local normalizedQuery = if query then query:lower():gsub("%s+", "") else ""
    local queryLength = #normalizedQuery
    local queryBytes = table.create(queryLength) :: { number }
    local isWord = queryLength > 0

    for idx = 1, queryLength do
        local byte = normalizedQuery:byte(idx)
        queryBytes[idx] = byte

        if not IsWordByte(byte) then
            isWord = false
        end
    end

    return {
        Text = normalizedQuery,
        Bytes = queryBytes,
        Length = queryLength,
        IsShortWord = queryLength < MinLooseMatchLength and isWord
    }
end

-- Scores an ordered subsequence in O(query length * candidate length).
-- Consecutive and word-boundary matches are preferred, while gaps are penalised.
local function ScoreSubsequence(
    candidate: Candidate,
    query: PreparedQuery
): number?
    local candidateBytes = candidate.CompactBytes
    local candidateLength = #candidateBytes
    local queryLength = query.Length

    if queryLength > candidateLength then return nil end

    local previousScores = table.create(candidateLength, NegativeInfinity)
    local scores = table.create(candidateLength, NegativeInfinity)
    local firstQueryByte = query.Bytes[1]

    -- Require a boundary for the first loose subsequence match.
    for candidateIdx = 1, candidateLength do
        if
            candidateBytes[candidateIdx] == firstQueryByte and
            candidate.BoundaryBonuses[candidateIdx] > 0
        then
            previousScores[candidateIdx] =
                candidate.BoundaryBonuses[candidateIdx] -
                (candidateIdx - 1) * GapPenalty
        end
    end

    for queryIdx = 2, queryLength do
        local queryByte = query.Bytes[queryIdx]
        local bestGapScore = NegativeInfinity

        for candidateIdx = 1, candidateLength do
            scores[candidateIdx] = NegativeInfinity

            local previousGapIdx = candidateIdx - 2
            if previousGapIdx >= 1 then
                bestGapScore = math.max(
                    bestGapScore,
                    previousScores[previousGapIdx] +
                        previousGapIdx * GapPenalty
                )
            end

            if candidateBytes[candidateIdx] ~= queryByte then
                continue
            end

            local bestScore = NegativeInfinity

            if candidateIdx > 1 then
                bestScore =
                    previousScores[candidateIdx - 1] + ConsecutiveBonus
            end

            if bestGapScore > NegativeInfinity then
                bestScore = math.max(
                    bestScore,
                    bestGapScore - (candidateIdx - 1) * GapPenalty
                )
            end

            if bestScore > NegativeInfinity then
                scores[candidateIdx] =
                    bestScore + candidate.BoundaryBonuses[candidateIdx]
            end
        end

        previousScores, scores = scores, previousScores
    end

    local bestScore = NegativeInfinity
    for candidateIdx = 1, candidateLength do
        local score = previousScores[candidateIdx]

        if score > NegativeInfinity then
            score -= (candidateLength - candidateIdx) * GapPenalty
            bestScore = math.max(bestScore, score)
        end
    end

    return if bestScore > NegativeInfinity then bestScore else nil
end

local function ScoreCandidate(
    candidate: Candidate,
    query: PreparedQuery
): number?
    local candidateText = candidate.Compact
    local queryText = query.Text
    local lengthPenalty = #candidateText - query.Length

    if candidateText == queryText then
        return ExactScore
    end

    local substringStart = candidateText:find(queryText, 1, true)
    if substringStart == 1 then
        return PrefixScore - lengthPenalty
    end

    if candidate.BoundaryCharacters:find(queryText, 1, true) == 1 then
        return BoundaryScore - lengthPenalty
    end

    while substringStart do
        if
            not query.IsShortWord or
            candidate.BoundaryBonuses[substringStart] > 0
        then
            return
                SubstringScore -
                (substringStart - 1) * 100 -
                lengthPenalty
        end

        substringStart = candidateText:find(queryText, substringStart + 1, true)
    end

    -- Short queries only use the stronger match tiers above.
    if query.IsShortWord then return nil end

    local subsequence = ScoreSubsequence(candidate, query)
    if not subsequence then return nil end

    return SubsequenceScore + subsequence * 10 - lengthPenalty
end

local function CompareScoredItems(
    leftScoredItem: ScoredItem,
    rightScoredItem: ScoredItem
): boolean
    if leftScoredItem.Score ~= rightScoredItem.Score then
        return leftScoredItem.Score > rightScoredItem.Score
    end

    local leftPreparedItem = leftScoredItem.PreparedItem
    local rightPreparedItem = rightScoredItem.PreparedItem

    if leftPreparedItem.LowerKey ~= rightPreparedItem.LowerKey then
        return leftPreparedItem.LowerKey < rightPreparedItem.LowerKey
    end

    if leftPreparedItem.Key ~= rightPreparedItem.Key then
        return leftPreparedItem.Key < rightPreparedItem.Key
    end

    return leftPreparedItem.Idx < rightPreparedItem.Idx
end

local function CreateItemFilter(items: { Item }): ItemFilter
    local preparedItems = table.create(#items) :: { PreparedItem }

    for idx, item in items do
        preparedItems[idx] = PrepareItem(item, idx)
    end

    return function(query: string?): { Item }
        local preparedQuery = PrepareQuery(query)
        if preparedQuery.Length == 0 then return items end

        local scoredItems = table.create(#items) :: { ScoredItem }
        local scoredItemCount = 0

        for _, preparedItem in preparedItems do
            RefreshPreparedItem(preparedItem)

            local score =
                ScoreCandidate(preparedItem.Candidate, preparedQuery)
            if not score then continue end

            scoredItemCount += 1
            scoredItems[scoredItemCount] = {
                PreparedItem = preparedItem,
                Score = score
            }
        end

        table.sort(scoredItems, CompareScoredItems)

        local filteredItems = table.create(scoredItemCount) :: { Item }
        for idx, scoredItem in scoredItems do
            filteredItems[idx] = scoredItem.PreparedItem.Item
        end

        return filteredItems
    end
end

return CreateItemFilter
