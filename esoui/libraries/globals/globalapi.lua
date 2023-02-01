-- Cached versions of the lua library functions

ZO_PI = math.pi
ZO_TWO_PI = ZO_PI * 2
ZO_HALF_PI = ZO_PI / 2

zo_strlower         = LocaleAwareToLower
zo_strupper         = LocaleAwareToUpper

string.lowerbybyte  = string.lower
string.upperbybyte  = string.upper

string.lower        = zo_strlower
string.upper        = zo_strupper

zo_strsub           = string.sub
zo_strgsub          = string.gsub
zo_strlen           = string.len
zo_strmatch         = string.match
zo_strgmatch        = string.gmatch
zo_strfind          = string.find
zo_plainstrfind     = PlainStringFind
zo_strsplit         = SplitString
zo_loadstring       = LoadString

zo_floor            = math.floor
zo_ceil             = math.ceil
zo_mod              = math.fmod
zo_decimalsplit     = math.modf
zo_abs              = math.abs
zo_max              = math.max
zo_min              = math.min
zo_sqrt             = math.sqrt
zo_pow              = math.pow
zo_cos              = math.cos
zo_sin              = math.sin
zo_tan              = math.tan
zo_atan2            = math.atan2
zo_randomseed       = math.randomseed
zo_random           = math.random
zo_insecureNext     = InsecureNext

function zo_randomDecimalRange(min, max)
    return zo_lerp(min, max, zo_random())
end

function zo_insecurePairs(t)
    return zo_insecureNext, t, nil
end

function zo_sign(value)
    if value == 0 then
        return 0
    end
    return value > 0 and 1 or -1
end

local function DefaultComparator(left, _, right)
    return left - right
end

function zo_binarysearch(searchData, dataList, comparator)
    comparator = comparator or DefaultComparator
    local low, high = 1, #dataList
    local mid = 0
    
    while low <= high do
        mid = zo_floor( (low + high) / 2)
        local compareVal = comparator(searchData, dataList[mid], mid)        
        if(compareVal == 0) then
            return true, mid
        elseif(compareVal < 0) then
            high = mid - 1
        else
            low = mid + 1
        end
    end
    
    high = zo_max(high, 1)
    local numEntries = #dataList
    while(high <= numEntries) do
        if(comparator(searchData, dataList[high], high) < 0) then
            return false, high
        end
        high = high + 1
    end
    
    return false, high
end

function zo_binaryinsert(item, searchData, dataList, comparator)
    local _, insertPosition = zo_binarysearch(searchData, dataList, comparator)
    table.insert(dataList, insertPosition, item)
end

function zo_binaryremove(searchData, dataList, comparator)
    local found, removePosition = zo_binarysearch(searchData, dataList, comparator)
    if found then
        table.remove(dataList, removePosition)
    end
end

function zo_clamp(value, minimum, maximum)
    if(value < minimum) then return minimum end
    if(value > maximum) then return maximum end
    return value
end

function zo_saturate(value)
    return zo_clamp(value, 0.0, 1.0)
end

function zo_round(value)
    return (value >= 0) and zo_floor(value + 0.5) or zo_ceil(value - 0.5)
end

function zo_roundToZero(value, precision)
    if precision == 0 then
        return value
    end
    precision = precision or 1
    local roundFunction = (value > 0) and zo_floor or zo_ceil
    return roundFunction(value * (1 / precision)) * precision
end

function zo_roundToEven(value, precision)
    if precision == 0 then
        return value
    end
    precision = precision or 1
    local floorValue = zo_floor(value * (1 / precision))
    if floorValue % 2 == 0 then
        return floorValue * precision
    else
        return (floorValue + 1) * precision
    end
end

function zo_roundToNearest(value, precision)
    if precision == 0 then
        return value
    end
    return zo_round(value * (1 / precision)) * precision
end

function zo_strjoin(separator, ...)
    return table.concat({...}, separator)
end

-- Expected range for amount: [0, 1]
function zo_lerp(from, to, amount)
    return from + amount * (to - from)
end

-- Expected range for amount: [0, 1]
function zo_lerpVector(from, to, amount)
    local numElements = #from
    local interpolatedElements = {}
    for index = 1, numElements do
        interpolatedElements[index] = from[index] + amount * (to[index] - from[index])
    end
    return interpolatedElements
end

function zo_frameDeltaNormalizedForTargetFramerate()
    return GetFrameDeltaNormalizedForTargetFramerate()
end

function zo_deltaNormalizedLerp(from, to, amount)
    return zo_lerp(from, to, 1 - math.pow(1 - amount, GetFrameDeltaNormalizedForTargetFramerate()))
end

function zo_percentBetween(startValue, endValue, value)
    if startValue == endValue then
        return 0.0
    end

    return (value - startValue) / (endValue - startValue);
end

function zo_clampedPercentBetween(startValue, endValue, value)
    return zo_saturate(zo_percentBetween(startValue, endValue, value))
end

function zo_floatsAreEqual(a, b, epsilon)
    epsilon = epsilon or 0.001
    return(zo_abs(a - b) <= epsilon)
end

-- Parses the first unsigned integer from a string or returns s if s is not a string.
function zo_parseUnsignedInteger(s)
    if type(s) == "string" then
        return tonumber(s:match("(%d+)"))
    end
    return s
end

function zo_iconFormat(path, width, height)
    return string.format("|t%s:%s:%s|t", tostring(width), tostring(height), path)
end

function zo_iconFormatInheritColor(path, width, height)
    return string.format("|t%s:%s:%s:inheritcolor|t", tostring(width), tostring(height), path)
end

function zo_iconTextFormat(path, width, height, text, inheritColor)
    local iconFormatter = zo_iconFormat
    if inheritColor then
        iconFormatter = zo_iconFormatInheritColor
    end
    return string.format("%s %s", iconFormatter(path, width, height), zo_strformat("<<1>>", text))
end

function zo_iconTextFormatNoSpace(path, width, height, text, inheritColor)
    local iconFormatter = zo_iconFormat
    if inheritColor then
        iconFormatter = zo_iconFormatInheritColor
    end
    return string.format("%s%s", iconFormatter(path, width, height), zo_strformat("<<1>>", text))
end

function zo_iconTextFormatNoSpaceAlignedRight(path, width, height, text, inheritColor)
    local iconFormatter = zo_iconFormat
    if inheritColor then
        iconFormatter = zo_iconFormatInheritColor
    end
    return string.format("%s%s", zo_strformat("<<1>>", text), iconFormatter(path, width, height))
end

function zo_bulletFormat(label, text)
    local bulletSpacer = GetString(SI_FORMAT_BULLET_SPACING)
    local bulletSpacingWidth = label:GetStringWidth(bulletSpacer)
    label:SetNewLineX(bulletSpacingWidth)
    label:SetText(zo_strformat(SI_FORMAT_BULLET_TEXT, text))
end

function zo_strikethroughTextFormat(text)
   return string.format("|L0:0:0:45%%:8%%:ignore|l%s|l", text)
end

function zo_callHandler(object, handler, ...)
    local handlerFunction = object:GetHandler(handler)
    if handlerFunction then
        handlerFunction(object, ...)
        return true
    end
    return false
end

local ZO_CallLaterId = 1

function zo_callLater(func, ms)
    local id = ZO_CallLaterId
    local name = "CallLaterFunction"..id
    ZO_CallLaterId = ZO_CallLaterId + 1

    EVENT_MANAGER:RegisterForUpdate(name, ms,
        function()
            EVENT_MANAGER:UnregisterForUpdate(name)
            func(id)
        end)
    return id
end

function zo_removeCallLater(id)
    EVENT_MANAGER:UnregisterForUpdate("CallLaterFunction"..id)
end

do
    local workingTable = {}
    function zo_replaceInVarArgs(indexToReplace, itemToReplaceWith, ...)
        for i = 1, select("#", ...) do
            if i == indexToReplace then
                workingTable[i] = itemToReplaceWith
            else
                workingTable[i] = select(i, ...)
            end
        end
        return unpack(workingTable, 1, select("#", ...))
    end
end

function zo_mixin(object, ...)
    for i = 1, select("#", ...) do
        local source = select(i, ...)
        for k,v in pairs(source) do
            object[k] = v
        end
    end
end

function zo_forwardArcSize(startAngle, angle)
    return (angle - startAngle) % ZO_TWO_PI
end

function zo_backwardArcSize(startAngle, angle)
    return ZO_TWO_PI - zo_forwardArcSize(startAngle, angle)
end

function zo_arcSize(startAngle, angle)
    return zo_min(zo_forwardArcSize(startAngle, angle), zo_backwardArcSize(startAngle, angle))
end

-- id64s are stored as lua Number type, and sometimes generate the same hash key for very similar numbers. 
-- Use this function to get unique hash key for a given id64. 
function zo_getSafeId64Key(id)
    return Id64ToString(id)
end

function zo_distance(x1, y1, x2, y2)
    local diffX = x1 - x2
    local diffY = y1 - y2
    return zo_sqrt(diffX * diffX + diffY * diffY)
end

function zo_distance3D(x1, y1, z1, x2, y2, z2)
    local diffX = x1 - x2
    local diffY = y1 - y2
    local diffZ = z1 - z2
    return zo_sqrt(diffX * diffX + diffY * diffY + diffZ * diffZ)
end

function zo_normalize(value, min, max)
    return (value - min) / (max - min)
end

function zo_clampLength2D(x, y, maxLength)
    local distance = zo_sqrt(x * x + y * y)
    if distance == 0 then
        -- there is no valid angle for a 0-length vector
        return 0, 0
    end
    local angleRadians = math.atan2(y, x)
    distance = zo_clamp(distance, 0, maxLength)
    return math.cos(angleRadians) * distance, math.sin(angleRadians) * distance
end

-- Rotate 2D coordinates about the origin by the specified angle.
function ZO_Rotate2D(angle, x, y)
    local cosine = math.cos(angle)
    local sine = math.sin(angle)
    return x * cosine - y * sine, y * cosine + x * sine
end

function ZO_ScaleAndRotateTextureCoords(control, angle, originX, originY, scaleX, scaleY)
    -- protect against 1 / 0
    if scaleX == 0 then
        scaleX = 0.0001
    end
    if scaleY == 0 then
        scaleY = 0.0001
    end

    local scaleCoefficientX, scaleCoefficientY = 1 / scaleX, 1 / scaleY
    local topLeftX, topLeftY = ZO_Rotate2D(angle, -0.5 * scaleCoefficientX, -0.5 * scaleCoefficientY)
    local topRightX, topRightY = ZO_Rotate2D(angle,  0.5 * scaleCoefficientX, -0.5 * scaleCoefficientY)
    local bottomLeftX, bottomLeftY = ZO_Rotate2D(angle, -0.5 * scaleCoefficientX,  0.5 * scaleCoefficientY)
    local bottomRightX, bottomRightY = ZO_Rotate2D(angle,  0.5 * scaleCoefficientX,  0.5 * scaleCoefficientY)

    control:SetVertexUV(VERTEX_POINTS_TOPLEFT, originX + topLeftX, originY + topLeftY)
    control:SetVertexUV(VERTEX_POINTS_TOPRIGHT, originX + topRightX, originY + topRightY)
    control:SetVertexUV(VERTEX_POINTS_BOTTOMLEFT, originX + bottomLeftX, originY + bottomLeftY)
    control:SetVertexUV(VERTEX_POINTS_BOTTOMRIGHT, originX + bottomRightX, originY + bottomRightY)
end

-- Updates the control's texture coordinates to show a single cell of a texture atlas that is composed of uniformly sized cells.
-- Note that cellIndex is 0-based.
function ZO_SetTextureCell(control, numColumns, numRows, cellIndex)
    local cellX = cellIndex % numColumns
    local cellY = zo_floor(cellIndex / numColumns)
    local x1, x2 = cellX / numColumns, (cellX + 1) / numColumns
    local y1, y2 = cellY / numRows, (cellY + 1) / numRows
    control:SetTextureCoords(x1, x2, y1, y2)
end

-- Updates the control's texture coordinates to show a single cell of a texture atlas that is composed of uniformly sized cells,
-- based upon the number of cells, the interval of the animation loop and the number of seconds that have elapsed.
function ZO_SetTextureCellAnimation(control, numColumns, numRows, intervalSeconds, elapsedSeconds)
    local cellInterval = (elapsedSeconds % intervalSeconds) / intervalSeconds
    local cellIndex = zo_floor(numColumns * numRows * cellInterval)
    ZO_SetTextureCell(control, numColumns, numRows, cellIndex)
end

-- Iterator returns each sequential flag in the inclusive range defined by iterationBegin and iterationEnd.
-- For example:
--
--  for bitValue in ZO_FlagIterator(1, 4) do
--      d(bitValue)
--  end
--
-- Produces the output:
--  1
--  2
--  4
--
-- The same output is also produced by:
--
--  for bitValue in ZO_FlagIterator(4) do
--      d(bitValue)
--  end
function ZO_FlagIterator(iterationBeginOrEnd, iterationEnd)
    local iter = iterationBeginOrEnd
    if not iterationEnd then
        -- If iterationEnd is omitted then we can infer that:
        --  iterationBeginOrEnd is the desired ending bit value; and,
        --  iterationBeginOrEnd assumes the implicit value of 1.
        iterationEnd = iterationBeginOrEnd
        iter = 1
    end
    assert(iter > 0)
    assert(iter <= iterationEnd)
    return function()
        if iter <= iterationEnd then
            local ret = iter
            iter = iter * 2 -- BitLShift(iter, 1)
            return ret
        end
    end
end

function ZO_MaskHasFlag(mask, flag)
    return BitAnd(mask, flag) == flag
end

-- Iterator returns each flag set in the specified mask.
-- For example:
--
--  local mask = 11 -- 1011 in binary
--  for flag in ZO_MaskHasFlagsIterator(mask) do
--      d(flag)
--  end
--
-- Produces the output:
--  1
--  2
--  8
function ZO_MaskHasFlagsIterator(mask)
    local iter = 1
    return function()
        while iter <= mask do
            local currentFlag = iter
            iter = iter * 2 -- BitLShift(iter, 1)
            if BitAnd(mask, currentFlag) == currentFlag then
                return currentFlag
            end
        end
        return nil
    end
end

function ZO_ClearMaskFlag(mask, flag)
    if BitAnd(mask, flag) == flag then
        return mask - flag
    end
    return mask
end

function ZO_ClearMaskFlags(mask, ...)
    local flags = {...}
    for _, flag in ipairs(flags) do
        if BitAnd(mask, flag) == flag then
            mask = mask - flag
        end
    end
    return mask
end

function ZO_SetMaskFlag(mask, flag)
    if BitAnd(mask, flag) ~= flag then
        return mask + flag
    end
    return mask
end

function ZO_SetMaskFlags(mask, ...)
    local flags = {...}
    for _, flag in ipairs(flags) do
        if BitAnd(mask, flag) ~= flag then
            mask = mask + flag
        end
    end
    return mask
end

-- Returns nil if no flags have changed; otherwise,
-- Returns a table whose keys and values are the flags that
-- have changed and their new corresponding Boolean values.
function ZO_CompareMaskFlags(flagsBefore, flagsAfter)
    if flagsBefore == flagsAfter then
        -- No flags have changed.
        return
    end

    local changedFlags = nil
    -- Higher mask value of either the before or after mask.
    local maxFlagMask = zo_max(flagsBefore, flagsAfter)
    -- Begin with first bit mask.
    local currentFlagMask = 1

    while currentFlagMask <= maxFlagMask do
        -- The new ("after") flag bit value.
        local flagAfter = BitAnd(flagsAfter, currentFlagMask)

        -- Has this flag bit value changed?
        if flagAfter ~= BitAnd(flagsBefore, currentFlagMask) then
            if not changedFlags then
                -- Deferred table allocation for performance.
                changedFlags = {}
            end
            -- Key: Flag mask (such as 1 or 4 or 64, etc.)
            -- Value: Flag bit value (true or false)
            changedFlags[currentFlagMask] = flagAfter ~= 0
        end

        -- Left shift mask to next highest bit.
        currentFlagMask = currentFlagMask * 2
    end

    return changedFlags
end