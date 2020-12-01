-- Binary Util
--[[
	A utility class to write Binary (Byte) data to a table (Buffer).
	This data is safe to be sent over the network via Remote Event.
	
	Version: 1.1
	Last Update: 11/30/2020
	
	Author: Andrew Hamilton (orange451)
]]

local module = {}

--- Flip the buffer. A buffer should be flipped when operations will change around it.
-- @Param Buffer to be flipped.
function module:Flip(Buffer)
	Buffer['_CurrentBit'] = 0
	Buffer['_CurrentIndex'] = 1
end

--- Write a bit of data to the buffer
-- @Param Buffer to write to
-- @Param Bit to write
function module:WriteBit(Buffer, Bit)
	Bit = (Bit == true) or (Bit == 1)

	if ( not Buffer['_CurrentIndex'] ) then
		Buffer['_CurrentIndex'] = 1
	end
	local CurrentIndex = Buffer['_CurrentIndex']

	local CurrentVal = tonumber(Buffer[CurrentIndex]) or 0
	CurrentVal = bit32.lshift(CurrentVal, 1)
	if ( Bit ) then
		CurrentVal = bit32.bor(CurrentVal, 1)
	end

	Buffer[CurrentIndex] = CurrentVal

	Buffer['_CurrentBit'] = (tonumber(Buffer['_CurrentBit']) or 0) + 1
	if ( Buffer['_CurrentBit'] == 8 ) then
		Buffer['_CurrentBit'] = 0
		Buffer['_CurrentIndex'] += 1
	end

	warn("Wrote bit to buffer, but cannot read. Not yet implemented.")
end

--- Write a byte of data to the buffer
-- @Param Buffer to write to
-- @Param Byte to write
function module:WriteByte(Buffer, Byte)
	if ( not Buffer or type(Buffer) ~= "table" ) then
		error("Buffer must be of type table.")
		return
	end

	Byte = math.floor(tonumber(Byte) or 0)
	if ( Byte > 255 or Byte < 0 ) then
		Byte = bit32.band(Byte, 0xff)
	end

	if (not Buffer['_CurrentBit'] or Buffer['_CurrentBit'] == 0) then
		if ( not Buffer['_CurrentIndex'] ) then
			Buffer['_CurrentIndex'] = 1
		end
		Buffer[Buffer['_CurrentIndex']] = Byte
		Buffer['_CurrentIndex'] += 1
	else
		for i=1,8 do
			local bit = bit32.band(bit32.rshift(Byte, 8 - i), 1) == 1
			self:WriteBit(Buffer, bit)
		end
	end
end

-- Write a boolean to the buffer, expressed as a single byte.
-- @Param Buffer to write to
-- @Param Boolean vlaue
function module:WriteBool(Buffer, Bool)
	Bool = Bool == true
	self:WriteByte(Buffer, Bool and 1 or 0)
end

-- Write a short to the buffer, expressed as two bytes.
-- @Param Buffer to write to
-- @Param Short Value
function module:WriteShort(Buffer, Value)
	Value = math.floor(tonumber(Value) or 0)
	self:WriteByte(Buffer, bit32.rshift(Value, 8))
	self:WriteByte(Buffer, bit32.rshift(Value, 0))
end

--- Write an integer to the buffer, expressed as four bytes.
-- @Param Buffer to write to
-- @Param Integer value
function module:WriteInt(Buffer, Value)
	Value = math.floor(tonumber(Value) or 0)
	self:WriteByte(Buffer, bit32.rshift(Value, 24))
	self:WriteByte(Buffer, bit32.rshift(Value, 16))
	self:WriteByte(Buffer, bit32.rshift(Value,  8))
	self:WriteByte(Buffer, bit32.rshift(Value,  0))
end

--- Write a double to the buffer, expressed as 8 bytes.
-- @Param Buffer to write to
-- @Param Double Value
function module:WriteDouble(Buffer, Value)

	-- This is kind of hacky... Need a better WriteDouble implementation!
	if ( math.abs(Value) < 0.01 ) then
		for i=1,8 do
			self:WriteByte(Buffer, 0)
		end
		return
	end

	local anum = math.abs(Value)

	local mantissa, exponent = math.frexp(anum)
	exponent = exponent - 1
	mantissa = mantissa * 2 - 1
	local sign = Value ~= anum and 128 or 0
	exponent = exponent + 1023

	self:WriteByte(Buffer, sign + math.floor(exponent / 2^4))

	mantissa = mantissa * 2^4
	local currentmantissa = math.floor(mantissa)
	mantissa = mantissa - currentmantissa
	self:WriteByte(Buffer, (exponent % 2^4) * 2^4 + currentmantissa)

	for i= 3, 8 do
		mantissa = mantissa * 2^8
		currentmantissa = math.floor(mantissa)
		mantissa = mantissa - currentmantissa
		self:WriteByte(Buffer, currentmantissa)
	end
end

--- Write a string to the buffer, expressed as a "most" (4*len+1) bytes.
--- This function will record the length of each character as a byte, 
--- before writing the required amount of bytes to express that character
--- This supports up to UTF-32 strings
-- @Param Buffer to write to
-- @Param String Value
function module:WriteString(Buffer, String)
	String = tostring(String) or ""

	for i=1,string.len(String) do
		local Char = string.sub(String, i, i)
		local t = {}
		for j=1,4 do -- UTF32
			local Byte = string.byte(Char, j) or 0
			if ( Byte > 0 ) then
				t[#t+1] = Byte
			end
		end

		self:WriteByte(Buffer, #t)
		for i=1,#t do
			self:WriteByte(Buffer, t[i])
		end
	end
	self:WriteByte(Buffer, 0)
end

--- Write a Vector2 to the buffer, expressed as 2 doubles (16 bytes)
-- @Param Buffer to write to
-- @Param Double Value
function module:WriteVector2(Buffer, Vector)
	if ( not Vector or typeof(Vector) ~= "Vector3" ) then
		error("Vector must be of type Vector3")
		return
	end

	self:WriteDouble(Buffer, Vector.X)
	self:WriteDouble(Buffer, Vector.Y)
end


--- Write a Vector3 to the buffer, expressed as 3 doubles (24 bytes)
-- @Param Buffer to write to
-- @Param Double Value
function module:WriteVector3(Buffer, Vector)
	if ( not Vector or typeof(Vector) ~= "Vector3" ) then
		error("Vector must be of type Vector3")
		return
	end

	self:WriteDouble(Buffer, Vector.X)
	self:WriteDouble(Buffer, Vector.Y)
	self:WriteDouble(Buffer, Vector.Z)
end

--- Read a bit of data from the buffer. NOT YET IMPLEMENTED.
-- @Param Buffer to read from
function module:ReadBit(Buffer)
	if ( not Buffer or type(Buffer) ~= "table" ) then
		error("Buffer must be of type table.")
		return
	end

	if ( not Buffer['_CurrentIndex'] ) then
		Buffer['_CurrentIndex'] = 1
	end
	
	Buffer['_CurrentBit'] = (tonumber(Buffer['_CurrentBit']) or 0) + 1
	local CurrentByte = Buffer[Buffer['_CurrentIndex']]
	local Bit = bit32.band(bit32.rshift(CurrentByte, 8-Buffer['_CurrentBit']), 1) == 1
		
	if ( Buffer['_CurrentBit'] == 8 ) then
		Buffer['_CurrentBit'] = 0
		Buffer['_CurrentIndex'] += 1
	end
	
	return Bit
end

--- Read a byte of data from the buffer (8 bits)
-- @Param Buffer to read from
function module:ReadByte(Buffer)
	if ( not Buffer or type(Buffer) ~= "table" ) then
		error("Buffer must be of type table.")
		return
	end

	if ( not Buffer['_CurrentIndex'] ) then
		Buffer['_CurrentIndex'] = 1
	end

	if ( self:Remaining(Buffer) == 0 ) then
		return nil
	end
	
	if ( Buffer['_CurrentBit'] == 0 ) then
		Buffer['_CurrentIndex'] += 1	
		return Buffer[Buffer['_CurrentIndex']-1]
	else
		local Byte = 0
		for i=1,8 do
			Byte = bit32.lshift(Byte, 1)
			local Bit = self:ReadBit(Buffer)
			if ( Bit ) then
				Byte = bit32.bor(Byte, 1)
			end
		end
		
		return Byte
	end
end

--- Read a boolean from the buffer (1 byte)
-- @Param Buffer to read from
function module:ReadBool(Buffer)
	return self:ReadByte(Buffer) == 1
end

--- Read an integer from the buffer (4 bytes)
-- @Param Buffer to read from
function module:ReadInt(Buffer)
	local x = 0
	for i=1,4 do
		local Byte = self:ReadByte(Buffer)
		x = bit32.lshift(x, 8)
		x = bit32.bor(x, Byte)
	end

	return x
end

--- Read a short from the buffer (2 bytes)
-- @Param Buffer to read from
function module:ReadShort(Buffer)
	local x = 0
	for i=1,2 do
		local Byte = self:ReadByte(Buffer)
		x = bit32.lshift(x, 8)
		x = bit32.bor(x, Byte)
	end

	return x
end

--- Read a string from the buffer, reads at "most" (4*len+1) bytes. See {BinaryUtil#WriteString}
-- @Param Buffer to read from
function module:ReadString(Buffer)
	local str = ""
	while(true)do
		local len = self:ReadByte(Buffer)
		if ( len == 0 or not len ) then -- Terminate if we hit a nil or 0 byte
			break
		end

		local t = {}
		for i=1,len do
			local b = self:ReadByte(Buffer)
			if ( b and b > 0 ) then
				t[#t+1] = b
			end
		end

		local Char = string.char(unpack(t))
		str = str .. Char
	end

	return str
end

--- Read a double from the buffer (8 bytes)
-- @Param Buffer to read from
function module:ReadDouble(Buffer)
	local Byte1 = self:ReadByte(Buffer)
	local Byte2 = self:ReadByte(Buffer)

	local sign = 1
	local mantissa = Byte2 % 2^4
	for i = 3, 8 do
		mantissa = mantissa * 256 + (self:ReadByte(Buffer) or 0)
	end

	if Byte1 > 127 then sign = -1 end
	local exponent = (Byte1 % 128) * 2^4 + math.floor(Byte2 / 2^4)
	if exponent == 0 then
		return 0
	end

	mantissa = (math.ldexp(mantissa, -52) + 1) * sign
	return math.ldexp(mantissa, exponent - 1023)
end

--- Read a Vector2 from the buffer (16 bytes)
-- @Param Buffer to read from
function module:ReadVector2(Buffer)
	local X = self:ReadDouble(Buffer) or 0
	local Y = self:ReadDouble(Buffer) or 0

	return Vector2.new(X, Y)
end

--- Read a Vector3 from the buffer (24 bytes)
-- @Param Buffer to read from
function module:ReadVector3(Buffer)
	local X = self:ReadDouble(Buffer) or 0
	local Y = self:ReadDouble(Buffer) or 0
	local Z = self:ReadDouble(Buffer) or 0

	return Vector3.new(X, Y, Z)
end

--- Return how many bytes are left to read in the buffer.
-- @Param Buffer to read from
function module:Remaining(Buffer)
	if ( not Buffer or type(Buffer) ~= "table" ) then
		error("Buffer must be of type table.")
		return
	end

	return #Buffer - ((tonumber(Buffer['_CurrentIndex']) or 1)-1)
end

return module
