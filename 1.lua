
                            local mesh = enemy.Mesh or (enemy.getAvatarComponent2 and enemy:getAvatarComponent2())
                            if slua.isValid(mesh) then
                                if not mesh.LastHitboxUpdateVersion or mesh.LastHitboxUpdateVersion ~= _G.MagicUpdateVersion then
                                    mesh.bIsAKHitboxModded = false
                                end

                                if not mesh.bIsAKHitboxModded then
                                    pcall(function()
                                        local physAsset = mesh.PhysicsAssetOverride or (mesh.SkeletalMesh and mesh.SkeletalMesh.PhysicsAsset)
                                        if slua.isValid(physAsset) and physAsset.SkeletalBodySetups then
                                            local scaleHead = 1.0 + (_G.AK_GetVal("MAGIC_HEAD") / 100.0)
                                            local scaleBody = 1.0 + (_G.AK_GetVal("MAGIC_BODY") / 100.0)
                                            local scaleLegs = 1.0 + (_G.AK_GetVal("MAGIC_LEGS") / 100.0)

                                            local targetBones = {
                                                ["head"] = scaleHead, 
                                                ["pelvis"] = scaleBody, ["spine_03"] = scaleBody,
                                                ["thigh_l"] = scaleLegs, ["thigh_r"] = scaleLegs,
                                                ["calf_l"] = scaleLegs, ["calf_r"] = scaleLegs,   
                                                ["foot_l"] = scaleLegs, ["foot_r"] = scaleLegs    
                                            }

                                            if not _G.AK_HitboxBaseCache then _G.AK_HitboxBaseCache = {} end
                                            local physName = tostring(physAsset)
                                            if not _G.AK_HitboxBaseCache[physName] then _G.AK_HitboxBaseCache[physName] = {} end
                                            local baseCache = _G.AK_HitboxBaseCache[physName]

                                            local bodySetups = physAsset.SkeletalBodySetups
                                            local numBodies = type(bodySetups.Num) == "function" and bodySetups:Num() or #bodySetups

                                            for i = 0, numBodies - 1 do
                                                local bodySetup = type(bodySetups.Get) == "function" and bodySetups:Get(i) or bodySetups[i + 1]
                                                if slua.isValid(bodySetup) then
                                                    local bName = string.lower(tostring(bodySetup.BoneName))
                                                    local matchKey = nil
                                                    for k, _ in pairs(targetBones) do
                                                        if string.find(bName, k) then matchKey = k; break; end
                                                    end
                                                    
                                                    if matchKey then
                                                        local scaleFactor = targetBones[matchKey]
                                                        local aggGeom = bodySetup.AggGeom
                                                        
                                                        local boxElems = aggGeom and aggGeom.BoxElems or bodySetup.BoxElems
                                                        local sphereElems = aggGeom and aggGeom.SphereElems or bodySetup.SphereElems
                                                        local sphylElems = aggGeom and aggGeom.SphylElems or bodySetup.SphylElems
                                                        
                                                        if not baseCache[matchKey] then baseCache[matchKey] = {} end
                                                        local cacheNode = baseCache[matchKey]
                                                        
                                                        if boxElems then
                                                            local box = nil
                                                            pcall(function() box = type(boxElems.Get) == "function" and boxElems:Get(0) or boxElems[1] end)
                                                            if box then
                                                                if not cacheNode.Box then cacheNode.Box = { X = box.X, Y = box.Y, Z = box.Z } end
                                                                box.X = cacheNode.Box.X * scaleFactor; box.Y = cacheNode.Box.Y * scaleFactor; box.Z = cacheNode.Box.Z * scaleFactor
                                                                pcall(function() if type(boxElems.Set) == "function" then boxElems:Set(0, box) else boxElems[1] = box end end)
                                                                if aggGeom then aggGeom.BoxElems = boxElems else bodySetup.BoxElems = boxElems end
                                                            end
                                                        end

                                                        if sphereElems then
                                                            local sphere = nil
                                                            pcall(function() sphere = type(sphereElems.Get) == "function" and sphereElems:Get(0) or sphereElems[1] end)
                                                            if sphere then
                                                                if not cacheNode.Sphere then cacheNode.Sphere = { Radius = sphere.Radius } end
                                                                sphere.Radius = cacheNode.Sphere.Radius * scaleFactor
                                                                pcall(function() if type(sphereElems.Set) == "function" then sphereElems:Set(0, sphere) else sphereElems[1] = sphere end end)
                                                                if aggGeom then aggGeom.SphereElems = sphereElems else bodySetup.SphereElems = sphereElems end
                                                            end
                                                        end

                                                        if sphylElems then
                                                            local sphyl = nil
                                                            pcall(function() sphyl = type(sphylElems.Get) == "function" and sphylElems:Get(0) or sphylElems[1] end)
                                                            if sphyl then
                                                                if not cacheNode.Sphyl then cacheNode.Sphyl = { Radius = sphyl.Radius } end
                                                                sphyl.Radius = cacheNode.Sphyl.Radius * scaleFactor
                                                                pcall(function() if type(sphylElems.Set) == "function" then sphylElems:Set(0, sphyl) else sphylElems[1] = sphyl end end)
                                                                if aggGeom then aggGeom.SphylElems = sphylElems else bodySetup.SphylElems = sphylElems end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end)
                                    mesh.LastHitboxUpdateVersion = _G.MagicUpdateVersion
                                    mesh.bIsAKHitboxModded = true
                                end
                            end
