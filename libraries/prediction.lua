local module = {}
local eps = 1e-9
local function isZero(d)
	return (d > -eps and d < eps)
end

local function cuberoot(x)
	return (x > 0) and x ^ (1 / 3) or -((-x) ^ (1 / 3))
end

local function solveQuadric(c0, c1, c2)
	local p = c1 / (2 * c0)
	local q = c2 / c0
	local D = p * p - q

	if isZero(D) then
		return -p
	elseif D < 0 then
		return
	end

	local sqrt_D = math.sqrt(D)
	return sqrt_D - p, -sqrt_D - p
end

local function solveCubic(c0, c1, c2, c3)
	local A = c1 / c0
	local B = c2 / c0
	local C = c3 / c0

	local sq_A = A * A
	local p = (1 / 3) * (-(1 / 3) * sq_A + B)
	local q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)

	local cb_p = p * p * p
	local D = q * q + cb_p

	local num, s0, s1, s2

	if isZero(D) then
		if isZero(q) then
			s0 = 0
			num = 1
		else
			local u = cuberoot(-q)
			s0 = 2 * u
			s1 = -u
			num = 2
		end
	elseif D < 0 then
		local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
		local t = 2 * math.sqrt(-p)
		s0 = t * math.cos(phi)
		s1 = -t * math.cos(phi + math.pi / 3)
		s2 = -t * math.cos(phi - math.pi / 3)
		num = 3
	else
		local sqrt_D = math.sqrt(D)
		local u = cuberoot(sqrt_D - q)
		local v = -cuberoot(sqrt_D + q)
		s0 = u + v
		num = 1
	end

	local sub = (1 / 3) * A

	if num > 0 then s0 = s0 - sub end
	if num > 1 then s1 = s1 - sub end
	if num > 2 then s2 = s2 - sub end

	return s0, s1, s2
end

function module.solveQuartic(c0, c1, c2, c3, c4)
	local A = c1 / c0
	local B = c2 / c0
	local C = c3 / c0
	local D = c4 / c0

	local sq_A = A * A
	local p = -0.375 * sq_A + B
	local q = 0.125 * sq_A * A - 0.5 * A * B + C
	local r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

	local num, s0, s1, s2, s3

	if isZero(r) then
		local results = {solveCubic(1, 0, p, q)}
		num = #results
		s0, s1, s2 = results[1], results[2], results[3]
	else
		local results = {solveCubic(1, -0.5 * p, -r, 0.5 * r * p - 0.125 * q * q)}
		local z = results[1]

		local u = z * z - r
		local v = 2 * z - p

		if u < 0 and not isZero(u) then return end
		if v < 0 and not isZero(v) then return end

		if isZero(u) then u = 0 else u = math.sqrt(u) end
		if isZero(v) then v = 0 else v = math.sqrt(v) end

		local qPos = q >= 0

		do
			local res = {solveQuadric(1, qPos and -v or v, z - u)}
			num = #res
			s0, s1 = res[1], res[2]
		end

		do
			local res = {solveQuadric(1, qPos and v or -v, z + u)}
			local n2 = #res
			if num == 0 then
				s0, s1 = res[1], res[2]
			elseif num == 1 then
				s1, s2 = res[1], res[2]
			elseif num == 2 then
				s2, s3 = res[1], res[2]
			end
			num = num + n2
		end
	end

	local sub = 0.25 * A

	if num > 0 then s0 = s0 - sub end
	if num > 1 then s1 = s1 - sub end
	if num > 2 then s2 = s2 - sub end
	if num > 3 then s3 = s3 - sub end

	return {s3, s2, s1, s0}
end

local velHistory = {}
local velHistoryMax = 6

local function smoothVelocity(target, rawVel)
	local key = target and tostring(target)
	if not key then return rawVel end

	if not velHistory[key] then
		velHistory[key] = {}
	end

	local hist = velHistory[key]
	table.insert(hist, {vel = rawVel, time = tick()})
	if #hist > velHistoryMax then
		table.remove(hist, 1)
	end

	if #hist < 2 then return rawVel end

	local smoothed = Vector3.new(0, 0, 0)
	local totalWeight = 0

	for i, entry in ipairs(hist) do
		local weight = i / #hist
		local ageWeight = 1
		smoothed = smoothed + entry.vel * (weight * ageWeight)
		totalWeight = totalWeight + weight * ageWeight
	end

	smoothed = smoothed / totalWeight

	local currentWeight = 0.65
	return rawVel * (1 - currentWeight) + smoothed * currentWeight
end

local accelTrack = {}

local function predictAcceleration(target, currentVel)
	local key = target and tostring(target)
	if not key then return Vector3.zero end

	local now = tick()
	local last = accelTrack[key]

	if not last then
		accelTrack[key] = {vel = currentVel, time = now}
		return Vector3.zero
	end

	local dt = now - last.time
	if dt <= 0 or dt > 0.5 then
		accelTrack[key] = {vel = currentVel, time = now}
		return Vector3.zero
	end

	local accel = (currentVel - last.vel) / dt
	accelTrack[key] = {vel = currentVel, time = now}

	if accel.Magnitude > 500 then return Vector3.zero end

	return accel
end

local function iterativeSolve(origin, speed, gravity, targetPos, vel, maxTime, iters)
	iters = iters or 15
	maxTime = maxTime or 8

	local best = targetPos
	local bestDist = math.huge
	local g = gravity or workspace.Gravity

	for i = 1, iters do
		local t = (maxTime / iters) * i
		local predictedPos = targetPos + vel * t
		predictedPos = predictedPos - Vector3.new(0, 0.5 * g * t * t, 0)

		local dir = predictedPos - origin
		local flightTime = dir.Magnitude / speed

		local diff = math.abs(flightTime - t)
		if diff < bestDist then
			bestDist = diff
			best = predictedPos
		end

		if diff < 0.01 then
			return predictedPos
		end
	end

	return best
end

local function refineSolution(origin, speed, gravity, targetPos, vel, initialTime, playerGravity)
	if not initialTime or initialTime <= 0 then return nil end

	local t = initialTime
	local gEff = gravity - (playerGravity or 0)

	for _ = 1, 8 do
		local predictedPos = targetPos + vel * t
		local fall = 0.5 * gEff * t * t
		predictedPos = Vector3.new(predictedPos.X, predictedPos.Y - fall, predictedPos.Z)

		local dir = predictedPos - origin
		local expectedTime = dir.Magnitude / speed

		if math.abs(expectedTime - t) < 0.001 then
			return predictedPos, t
		end

		t = t * 0.7 + expectedTime * 0.3
		if t <= 0 or t > 20 then return nil end
	end

	return origin + (targetPos + vel * t - origin).Unit * speed * t
end

local function estimateTimeOfFlight(origin, targetPos, speed, vel)
	local disp = targetPos - origin
	local relVel = vel
	local a = relVel:Dot(relVel) - speed * speed
	local b = 2 * disp:Dot(relVel)
	local c = disp:Dot(disp)

	local discriminant = b * b - 4 * a * c
	if discriminant < 0 then return (disp.Magnitude / speed) end

	local sqrtD = math.sqrt(discriminant)
	local t1 = (-b + sqrtD) / (2 * a)
	local t2 = (-b - sqrtD) / (2 * a)

	if t1 > 0 and t2 > 0 then return math.min(t1, t2) end
	if t1 > 0 then return t1 end
	if t2 > 0 then return t2 end

	return disp.Magnitude / speed
end

local function computeGravityCompensation(targetPos, vel, playerGravity, playerHeight, params)
	if not playerGravity or playerGravity <= 0 or math.abs(vel.Y) < 0.01 then
		return targetPos, vel
	end

	local estTime = estimateTimeOfFlight(Vector3.zero, targetPos, 50, vel)
	estTime = math.clamp(estTime, 0.1, 5)

	local compensatedVel = Vector3.new(vel.X, vel.Y - playerGravity * estTime * 0.5, vel.Z)
	local compensatedPos = targetPos

	if params then
		for _ = 1, 3 do
			local ray = workspace:Raycast(compensatedPos, compensatedVel * estTime * 0.1, params)
			if ray then
				compensatedPos = ray.Position + Vector3.new(0, playerHeight or 2, 0)
				estTime = estimateTimeOfFlight(Vector3.zero, compensatedPos, 50, compensatedVel)
				compensatedVel = Vector3.new(vel.X, vel.Y - playerGravity * estTime * 0.5, vel.Z)
			else
				break
			end
		end
	end

	return compensatedPos, compensatedVel
end

function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params, ...)
	local disp = targetPos - origin
	local dist = disp.Magnitude

	if dist < 0.01 then return targetPos end

	local extraArgs = {...}
	local usePing = extraArgs[2] or 0
	if type(usePing) ~= 'number' then usePing = 0 end

	local effectiveVel = targetVelocity or Vector3.zero
	if playerJump and playerJump > 0 then
		effectiveVel = Vector3.new(effectiveVel.X, effectiveVel.Y + playerJump, effectiveVel.Z)
	end

	local smoothKey = tostring(targetPos)
	local smoothedVel = smoothVelocity(smoothKey, effectiveVel)

	local accel = predictAcceleration(smoothKey, effectiveVel)
	local predictedVel = smoothedVel + accel * 0.1

	local compensatedPos, compensatedVel = computeGravityCompensation(
		targetPos, predictedVel, playerGravity, playerHeight, params
	)

	local pingSeconds = usePing / 1000
	if pingSeconds > 0 then
		compensatedPos = compensatedPos + compensatedVel * pingSeconds
	end

	local newDisp = compensatedPos - origin
	local p, q, r = compensatedVel.X, compensatedVel.Y, compensatedVel.Z
	local h, j, k = newDisp.X, newDisp.Y, newDisp.Z
	local l = -0.5 * (gravity - (playerGravity or 0))

	local solutions
	if math.abs(l) > eps then
		solutions = module.solveQuartic(
			l * l,
			-2 * q * l,
			q * q - 2 * j * l - projectileSpeed * projectileSpeed + p * p + r * r,
			2 * j * q + 2 * h * p + 2 * k * r,
			j * j + h * h + k * k
		)
	end

	if solutions then
		local posRoots = {}
		for _, v in solutions do
			if v > 0 and v < 20 then
				table.insert(posRoots, v)
			end
		end
		table.sort(posRoots)

		local bestErr = math.huge
		local bestResult = nil
		local bestTime = nil

		for _, t in ipairs(posRoots) do
			local d = (h + p * t) / t
			local e = (j + q * t - l * t * t) / t
			local f = (k + r * t) / t

			local predictedPos = origin + Vector3.new(d, e, f)
			local aimDir = predictedPos - origin
			local flightTime = aimDir.Magnitude / projectileSpeed

			local err = math.abs(flightTime - t)
			if err < bestErr then
				bestErr = err
				bestResult = predictedPos
				bestTime = t
			end
		end

		if bestResult then
			local refined = refineSolution(origin, projectileSpeed, gravity, compensatedPos, compensatedVel, bestTime, playerGravity)
			if refined then
				return refined
			end
			return bestResult
		end
	end

	if math.abs(gravity) < eps then
		local t = newDisp.Magnitude / projectileSpeed
		if t <= 0 then return compensatedPos end
		local d = (h + p * t) / t
		local e = (j + q * t) / t
		local f = (k + r * t) / t
		return origin + Vector3.new(d, e, f)
	end

	return iterativeSolve(origin, projectileSpeed, gravity, compensatedPos, compensatedVel, dist / projectileSpeed * 1.5, 20)
end

return module
