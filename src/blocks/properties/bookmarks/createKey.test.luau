--!strict

local CreateKey = require("./createKey")

assert(
    CreateKey("Data", "Instance", "Name")
        == "Data/Instance/Name"
)
assert(
    CreateKey("Appearance", "BasePart", "Transparency")
        == "Appearance/BasePart/Transparency"
)
assert(
    CreateKey("Tags", "CollectionService", "Enemy")
        == "Tags/CollectionService/Enemy"
)
assert(
    CreateKey("Attributes", "Instance", "Health")
        == "Attributes/Instance/Health"
)

print("bookmark key verification passed")
