--!strict

type Item = { Key: string, Value: any }

type PreparedQuery = {
    Text: string,
    Bytes: { number },
    Length: number,
    IsShortWord: boolean
}

type Candidate = {
    Compact: string,
    CompactBytes: { number },
    BoundaryCharacters: string,
    BoundaryBonuses: { number }
}

type CachedCandidate = {
    Key: string,
    Candidate: Candidate
}

type ScoredItem = {
    Item: Item,
    Score: number,
    LowerKey: string,
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
local NegativeInfinity = -math.huge

-- Candidate values never refer back to their item key, so cache entries can be
-- collected as soon as the item is no longer reachable elsewhere.
local CandidateCache = setmetatable(
    {} :: { [Item]: CachedCandidate },
    { __mode = "k" }
) :: { [Item]: CachedCandidate }

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
    local compactCharacters = table.create(inputLength)
    local compactBytes = table.create(inputLength)
    local boundaryCharacters = table.create(inputLength)
    local boundaryBonuses = table.create(inputLength)
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
        Compact = table.concat(compactCharacters),
        CompactBytes = compactBytes,
        BoundaryCharacters = table.concat(boundaryCharacters),
        BoundaryBonuses = boundaryBonuses
    }
end

local function GetCandidate(item: Item): Candidate
    local key = item.Key
    local cached = CandidateCache[item]

    if cached and cached.Key == key then
        return cached.Candidate
    end

    local candidate = PrepareCandidate(key)
    CandidateCache[item] = {
        Key = key,
        Candidate = candidate
    }

    return candidate
end

local function PrepareQuery(query: string?): PreparedQuery
    local normalizedQuery = if query then query:lower():gsub("%s+", "") else ""
    local queryLength = #normalizedQuery
    local queryBytes = table.create(queryLength)
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
-- Consecutive and word-boundary matches are preferred while gaps are penalised.
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

    for candidateIdx = 1, candidateLength do
        if candidateBytes[candidateIdx] == firstQueryByte then
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

    -- Very short fuzzy matches are usually noise. They still match prefixes,
    -- camel-case initials, and boundary substrings through the tiers above.
    if query.IsShortWord then return nil end

    local subsequence = ScoreSubsequence(candidate, query)
    if not subsequence then return nil end

    return SubsequenceScore + subsequence * 10 - lengthPenalty
end

local function FilterItems(items: { Item }, query: string?): { Item }
    local preparedQuery = PrepareQuery(query)
    if preparedQuery.Length == 0 then return table.clone(items) end

    local scoredItems = table.create(#items) :: { ScoredItem }
    local scoredItemCount = 0

    for idx, item in items do
        local score = ScoreCandidate(GetCandidate(item), preparedQuery)
        if not score then continue end

        scoredItemCount += 1
        scoredItems[scoredItemCount] = {
            Item = item,
            Score = score,
            LowerKey = item.Key:lower(),
            Index = idx
        }
    end

    table.sort(scoredItems, function(a: ScoredItem, b: ScoredItem): boolean
        if a.Score ~= b.Score then return a.Score > b.Score end
        if a.LowerKey ~= b.LowerKey then return a.LowerKey < b.LowerKey end
        if a.Item.Key ~= b.Item.Key then return a.Item.Key < b.Item.Key end

        return a.Index < b.Index
    end)

    local filteredItems = table.create(scoredItemCount) :: { Item }
    for idx, scoredItem in scoredItems do
        filteredItems[idx] = scoredItem.Item
    end

    return filteredItems
end

return FilterItems
