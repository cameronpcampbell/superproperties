--!strict

const COLOR_SPACE_KIND_PREFIX = "ColorSpace:"
const COLOR_SPACE_KIND_PREFIX_LEN = #COLOR_SPACE_KIND_PREFIX

const COLOR_SPACE_CONSTR_KIND_PREFIX = "ColorSpaceConstr:"
const COLOR_SPACE_CONSTR_KIND_PREFIX_LEN = #COLOR_SPACE_CONSTR_KIND_PREFIX

local function singleton<T>(value: T | ""): T
    return value
end

local function srgbToLinear(channel: number): number
	if channel <= 0.04045 then
		return channel / 12.92
	else
		return ((channel + 0.055) / 1.055) ^ 2.4
	end
end

local function linearToSrgb(channel: number): number
	if channel <= 0.0031308 then
		return channel * 12.92
	else
		return 1.055 * channel ^ (1 / 2.4) - 0.055
	end
end

local DARK_LIGHTNESS_THRESHOLD = 0.5

-- Srgb

local Srgb = {
	kind = singleton("ColorSpaceConstr:Srgb"),
}
Srgb.__index = Srgb

export type Srgb = {
	red: number,
	green: number,
	blue: number,
	kind: "ColorSpace:Srgb",
}

export type SrgbClass = setmetatable<Srgb, typeof(Srgb)>

function Srgb.new(red: number, green: number, blue: number)
	return setmetatable({
		red = red,
		green = green,
		blue = blue,
		kind = singleton("ColorSpace:Srgb"),
	}, Srgb)
end

-- LinearRgb

local LinearRgb = {
	kind = singleton("ColorSpaceConstr:LinearRgb"),
}
LinearRgb.__index = LinearRgb

export type LinearRgb = {
	red: number,
	green: number,
	blue: number,
	kind: "ColorSpace:LinearRgb",
}

export type LinearRgbClass = setmetatable<LinearRgb, typeof(LinearRgb)>

function LinearRgb.new(red: number, green: number, blue: number)
	return setmetatable({
		red = red,
		green = green,
		blue = blue,
		kind = singleton("ColorSpace:LinearRgb"),
	}, LinearRgb)
end

-- Xyz

local Xyz = {
	kind = singleton("ColorSpaceConstr:Xyz"),
}
Xyz.__index = Xyz

export type Xyz = {
	x: number,
	y: number,
	z: number,
	kind: "ColorSpace:Xyz",
}

export type XyzClass = setmetatable<Xyz, typeof(Xyz)>

function Xyz.new(x: number, y: number, z: number)
	return setmetatable({
		x = x,
		y = y,
		z = z,
		kind = singleton("ColorSpace:Xyz"),
	}, Xyz)
end

-- Oklab

local Oklab = {
	kind = singleton("ColorSpaceConstr:Oklab"),
}
Oklab.__index = Oklab

export type Oklab = {
	lightness: number,
	a: number,
	b: number,
	kind: "ColorSpace:Oklab",
}

export type OklabClass = setmetatable<Oklab, typeof(Oklab)>

function Oklab.new(lightness: number, a: number, b: number)
	return setmetatable({
		lightness = lightness,
		a = a,
		b = b,
		kind = singleton("ColorSpace:Oklab"),
	}, Oklab)
end

-- Oklch

local Oklch = {
	kind = singleton("ColorSpaceConstr:Oklch"),
}
Oklch.__index = Oklch

export type Oklch = {
	lightness: number,
	chroma: number,
	hue: number,
	kind: "ColorSpace:Oklch",
}

export type OklchClass = setmetatable<Oklch, typeof(Oklch)>

function Oklch.new(lightness: number, chroma: number, hue: number)
	return setmetatable({
		lightness = lightness,
		chroma = chroma,
		hue = hue,
		kind = singleton("ColorSpace:Oklch"),
	}, Oklch)
end

-- Direct conversions: Srgb <-> LinearRgb

function Srgb.ToLinearRgb(self: SrgbClass)
	return LinearRgb.new(
		srgbToLinear(self.red),
		srgbToLinear(self.green),
		srgbToLinear(self.blue)
	)
end

function LinearRgb.ToSrgb(self: LinearRgbClass)
	return Srgb.new(
		math.clamp(linearToSrgb(self.red), 0, 1),
		math.clamp(linearToSrgb(self.green), 0, 1),
		math.clamp(linearToSrgb(self.blue), 0, 1)
	)
end

-- Direct conversions: LinearRgb <-> Xyz

function LinearRgb.ToXyz(self: LinearRgbClass)
	local r: number = self.red
	local g: number = self.green
	local b: number = self.blue

	return Xyz.new(
		0.4124564 * r + 0.3575761 * g + 0.1804375 * b,
		0.2126729 * r + 0.7151522 * g + 0.0721750 * b,
		0.0193339 * r + 0.1191920 * g + 0.9503041 * b
	)
end

function Xyz.ToLinearRgb(self: XyzClass)
	return LinearRgb.new(
		 3.2404542 * self.x - 1.5371385 * self.y - 0.4985314 * self.z,
		-0.9692660 * self.x + 1.8760108 * self.y + 0.0415560 * self.z,
		 0.0556434 * self.x - 0.2040259 * self.y + 1.0572252 * self.z
	)
end

-- Direct conversions: LinearRgb <-> Oklab

function LinearRgb.ToOklab(self: LinearRgbClass)
	local r: number = self.red
	local g: number = self.green
	local b: number = self.blue

	local l: number = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
	local m: number = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
	local s: number = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)

	return Oklab.new(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	)
end

function Oklab.ToLinearRgb(self: OklabClass)
	local l: number = (self.lightness + 0.3963377774 * self.a + 0.2158037573 * self.b) ^ 3
	local m: number = (self.lightness - 0.1055613458 * self.a - 0.0638541728 * self.b) ^ 3
	local s: number = (self.lightness - 0.0894841775 * self.a - 1.2914855480 * self.b) ^ 3

	return LinearRgb.new(
		 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	)
end

-- Direct conversions: Oklab <-> Oklch

function Oklab.ToOklch(self: OklabClass)
	return Oklch.new(
		self.lightness,
		math.sqrt(self.a ^ 2 + self.b ^ 2),
		math.atan2(self.b, self.a)
	)
end

function Oklch.ToOklab(self: OklchClass)
	return Oklab.new(
		self.lightness,
		self.chroma * math.cos(self.hue),
		self.chroma * math.sin(self.hue)
	)
end

-- Chained conversions: Srgb

function Srgb.ToXyz(self: SrgbClass)
	return self:ToLinearRgb():ToXyz()
end

function Srgb.ToOklab(self: SrgbClass)
	return self:ToLinearRgb():ToOklab()
end

function Srgb.ToOklch(self: SrgbClass)
	return self:ToLinearRgb():ToOklab():ToOklch()
end

-- Chained conversions: LinearRgb

function LinearRgb.ToOklch(self: LinearRgbClass)
	return self:ToOklab():ToOklch()
end

-- Chained conversions: Xyz

function Xyz.ToSrgb(self: XyzClass)
	return self:ToLinearRgb():ToSrgb()
end

function Xyz.ToOklab(self: XyzClass)
	return self:ToLinearRgb():ToOklab()
end

function Xyz.ToOklch(self: XyzClass)
	return self:ToLinearRgb():ToOklab():ToOklch()
end

-- Chained conversions: Oklab

function Oklab.ToSrgb(self: OklabClass)
	return self:ToLinearRgb():ToSrgb()
end

function Oklab.ToXyz(self: OklabClass)
	return self:ToLinearRgb():ToXyz()
end

-- Chained conversions: Oklch

function Oklch.ToLinearRgb(self: OklchClass)
	return self:ToOklab():ToLinearRgb()
end

function Oklch.ToSrgb(self: OklchClass)
	return self:ToOklab():ToLinearRgb():ToSrgb()
end

function Oklch.ToXyz(self: OklchClass)
	return self:ToOklab():ToLinearRgb():ToXyz()
end

-- Lerp

function Srgb.Lerp(self: SrgbClass, other: SrgbClass, alpha: number)
	return Srgb.new(
		self.red + (other.red - self.red) * alpha,
		self.green + (other.green - self.green) * alpha,
		self.blue + (other.blue - self.blue) * alpha
	)
end

function LinearRgb.Lerp(self: LinearRgbClass, other: LinearRgbClass, alpha: number)
	return LinearRgb.new(
		self.red + (other.red - self.red) * alpha,
		self.green + (other.green - self.green) * alpha,
		self.blue + (other.blue - self.blue) * alpha
	)
end

function Xyz.Lerp(self: XyzClass, other: XyzClass, alpha: number)
	return Xyz.new(
		self.x + (other.x - self.x) * alpha,
		self.y + (other.y - self.y) * alpha,
		self.z + (other.z - self.z) * alpha
	)
end

function Oklab.Lerp(self: OklabClass, other: OklabClass, alpha: number)
	return Oklab.new(
		self.lightness + (other.lightness - self.lightness) * alpha,
		self.a + (other.a - self.a) * alpha,
		self.b + (other.b - self.b) * alpha
	)
end

function Oklch.Lerp(self: OklchClass, other: OklchClass, alpha: number)
	local tau: number = 2 * math.pi
	local delta: number = (other.hue - self.hue) % tau
	if delta > math.pi then
		delta -= tau
	end

	return Oklch.new(
		self.lightness + (other.lightness - self.lightness) * alpha,
		self.chroma + (other.chroma - self.chroma) * alpha,
		self.hue + delta * alpha
	)
end

-- Components

function Srgb.Components(self: SrgbClass): (number, number, number)
	return self.red, self.green, self.blue
end

function LinearRgb.Components(self: LinearRgbClass): (number, number, number)
	return self.red, self.green, self.blue
end

function Xyz.Components(self: XyzClass): (number, number, number)
	return self.x, self.y, self.z
end

function Oklab.Components(self: OklabClass): (number, number, number)
	return self.lightness, self.a, self.b
end

function Oklch.Components(self: OklchClass): (number, number, number)
	return self.lightness, self.chroma, self.hue
end

-- Color3 interop

function Srgb.ToColor3(self: SrgbClass): Color3
	return Color3.new(self.red, self.green, self.blue)
end

function LinearRgb.ToColor3(self: LinearRgbClass): Color3
	return self:ToSrgb():ToColor3()
end

function Xyz.ToColor3(self: XyzClass): Color3
	return self:ToSrgb():ToColor3()
end

function Oklab.ToColor3(self: OklabClass): Color3
	return self:ToSrgb():ToColor3()
end

function Oklch.ToColor3(self: OklchClass): Color3
	return self:ToSrgb():ToColor3()
end

-- Stringification

function Srgb.ToHexString(self: SrgbClass): string
	return string.format(
		"#%02X%02X%02X",
		math.round(self.red * 255),
		math.round(self.green * 255),
		math.round(self.blue * 255)
	)
end

function LinearRgb.ToHexString(self: LinearRgbClass): string
	return self:ToSrgb():ToHexString()
end

function Xyz.ToHexString(self: XyzClass): string
	return self:ToSrgb():ToHexString()
end

function Oklab.ToHexString(self: OklabClass): string
	return self:ToSrgb():ToHexString()
end

function Oklch.ToHexString(self: OklchClass): string
	return self:ToSrgb():ToHexString()
end

-- Appearance

function Oklab.IsDark(self: OklabClass): boolean
	return self.lightness <= DARK_LIGHTNESS_THRESHOLD
end

function Oklab.IsLight(self: OklabClass): boolean
	return not self:IsDark()
end

function Srgb.IsDark(self: SrgbClass): boolean
	return self:ToOklab():IsDark()
end

function Srgb.IsLight(self: SrgbClass): boolean
	return not self:IsDark()
end

function LinearRgb.IsDark(self: LinearRgbClass): boolean
	return self:ToOklab():IsDark()
end

function LinearRgb.IsLight(self: LinearRgbClass): boolean
	return not self:IsDark()
end

function Xyz.IsDark(self: XyzClass): boolean
	return self:ToOklab():IsDark()
end

function Xyz.IsLight(self: XyzClass): boolean
	return not self:IsDark()
end

function Oklch.IsDark(self: OklchClass): boolean
	return self:ToOklab():IsDark()
end

function Oklch.IsLight(self: OklchClass): boolean
	return not self:IsDark()
end

export type AnyColor =
    SrgbClass | LinearRgbClass | XyzClass | OklabClass | OklchClass | Color3
export type AnyColorConstructor =
    typeof(Srgb) | typeof(LinearRgb) | typeof(Xyz) | typeof(Oklab) | typeof(Oklch) | "Color3"

local function from(color: AnyColor, targetSpace: AnyColorConstructor)
	local colorName: string =
		if typeof(color) == "Color3" then "Color3"
		else string.sub((color :: any).kind, COLOR_SPACE_KIND_PREFIX_LEN + 1)

	local targetSpaceName: string =
		if targetSpace == "Color3" then "Color3"
		else string.sub((targetSpace :: any).kind, COLOR_SPACE_CONSTR_KIND_PREFIX_LEN + 1)

	if colorName == targetSpaceName then
		return color
	end

	local source: any = color

	if colorName == "Color3" then
		source = Srgb.new((color :: Color3).R, (color :: Color3).G, (color :: Color3).B)

		if targetSpaceName == "Srgb" then
			return source
		end
	end

	if targetSpaceName == "Color3" then
		return source:ToColor3()
	end

	return source["To" .. targetSpaceName](source)
end

function Srgb.From(color: AnyColor): SrgbClass
	return from(color, Srgb) :: SrgbClass
end

function LinearRgb.From(color: AnyColor): LinearRgbClass
	return from(color, LinearRgb) :: LinearRgbClass
end

function Xyz.From(color: AnyColor): XyzClass
	return from(color, Xyz) :: XyzClass
end

function Oklab.From(color: AnyColor): OklabClass
	return from(color, Oklab) :: OklabClass
end

function Oklch.From(color: AnyColor): OklchClass
	return from(color, Oklch) :: OklchClass
end

return {
	Srgb = Srgb,
	LinearRgb = LinearRgb,
	Xyz = Xyz,
	Oklab = Oklab,
	Oklch = Oklch,
}
