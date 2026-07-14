--!strict
local ReflectionService = game:GetService("ReflectionService")

local Packages = script.Parent.Parent.Parent.Parent.Parent.packages
local Typeforge = require(Packages.typeforge)

export type ReflectedProperties =
    index<Typeforge.Returns<typeof(ReflectionService.GetPropertiesOfClass)>, "1">

export type ReflectionPropertiesItem = index<ReflectedProperties, number>

export type PatchedReflectionPropertiesItem = Typeforge.Flatten<
    ReflectionPropertiesItem & {
        CustomReadWrite: {
            Read: (instance: any) -> any,
            Write: (instance: any, value: any) -> (),
            Observe: ((
                instance: any,
                callback: () -> ()
            ) -> RBXScriptConnection?)?
        }?
    }
>

return nil
