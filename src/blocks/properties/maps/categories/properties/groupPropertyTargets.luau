--!strict

export type Candidate<T> = {
    Id: string,
    OwnerName: string,
    Name: string,
    CategoryName: string,
    ValueType: string,
    Target: T,
    Writable: boolean,
    Warning: boolean
}

export type Group<T> = {
    Id: string,
    OwnerName: string,
    Name: string,
    CategoryName: string,
    ValueType: string,
    Targets: { T },
    AllWritable: boolean,
    Warning: boolean
}

return function<T>(
    candidates: { Candidate<T> }
): ({ Group<T> }, { string })
    local groupsById: { [string]: Group<T> } = {}
    local groups = {} :: { Group<T> }
    local categoryNames = {} :: { string }
    local seenCategoryNames: { [string]: boolean } = {}

    for _, candidate in candidates do
        local existingGroup = groupsById[candidate.Id]
        local group: Group<T>

        if existingGroup then
            group = existingGroup
        else
            group = {
                Id = candidate.Id,
                OwnerName = candidate.OwnerName,
                Name = candidate.Name,
                CategoryName = candidate.CategoryName,
                ValueType = candidate.ValueType,
                Targets = {},
                AllWritable = true,
                Warning = false
            }
            groupsById[candidate.Id] = group
            table.insert(groups, group)

            if not seenCategoryNames[group.CategoryName] then
                seenCategoryNames[group.CategoryName] = true
                table.insert(categoryNames, group.CategoryName)
            end
        end

        table.insert(group.Targets, candidate.Target)
        if not candidate.Writable then group.AllWritable = false end
        if candidate.Warning then group.Warning = true end
    end

    return groups, categoryNames
end
