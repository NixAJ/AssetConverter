function ProjectTemplate(name, projectType, sourceDir, binDir, dependencies, defs, cppVersion)
    local internalName = "Project-" .. name
    if _G[internalName] ~= nil then
        error("Attempted to create project '" .. name .. "' but a project with the same name already exists")
    end

    print("Creating Project '" .. name .. "'")
    _G[internalName] = { }

    if cppVersion == nil or cppVersion == "" then
        cppVersion = "C++17"
    else
        local version = tonumber(cppVersion)

        if version ~= nil then
            cppVersion = tostring(version)
        end

        if cppVersion == "03" then
            cppVersion = "C++03"
        elseif cppVersion == "11" then
            cppVersion = "C++11"
        elseif cppVersion == "14" then
            cppVersion = "C++14"
        elseif cppVersion == "17" then
            cppVersion = "C++17"
        elseif cppVersion == "20" then
            cppVersion = "C++20"
        elseif cppVersion == "23" then
            cppVersion = "C++23"
        end

        if not cppVersion:find("^C++") then
            cppVersion = "C++17"
        end
    end

    local resolvedDependencies = { }
    local needToResolve = true

    for k, v in pairs(dependencies) do
        resolvedDependencies[v] = v
    end

    while needToResolve do
        local numAddedDependencies = 0

        for k, v in pairs(resolvedDependencies) do
            local depInternalName = "Dependency-" .. v

            local dep = _G[depInternalName]
            if (dep == nil) then
                error("Attempted to use undeclared dependency '" .. v .. "' in project '" .. name .. "'")
            end

            if resolvedDependencies[v] == nil then
                resolvedDependencies[v] = v
                numAddedDependencies = numAddedDependencies + 1
            end

            if dep.Dependencies ~= nil then
                local deps = nil

                if type(dep.Dependencies) == "function" then
                    deps = dep.Dependencies()
                elseif type(dep.Dependencies) == "table" or type(dep.Dependencies) == "string" then
                    deps = dep.Dependencies
                end

                if deps ~= nil then
                    for k, v in pairs(deps) do
                        if resolvedDependencies[v] == nil then
                            resolvedDependencies[v] = v
                            numAddedDependencies = numAddedDependencies + 1
                        end
                    end
                end
            end
        end

        needToResolve = numAddedDependencies > 0
    end

    project (name)
        kind (projectType)
        language "C++"
        cppdialect (cppVersion)
        targetdir (AssetConverter.binDir .. "/%{cfg.buildcfg}")
        characterset ("ASCII")
        vpaths { ["*"] = name }

        if sourceDir ~= nil then
            files
            {
                (sourceDir .. "/**.h"),
                (sourceDir .. "/**.hpp"),
                (sourceDir .. "/**.cpp")
            }
            includedirs { path.getabsolute(sourceDir) }
        end

        links { }
        defines { defs }

        for k, v in pairs(resolvedDependencies) do
            local depInternalName = "Dependency-" .. v
            if (_G[depInternalName].Callback ~= nil) then
                _G[depInternalName].Callback()
                filter {}
            end
        end

        filter "configurations:Debug"
            runtime "Debug"
            symbols "On"
            defines { "NC_DEBUG" }

        filter "configurations:RelDebug"
            defines { "NC_RELEASE" }
            runtime "Release"
            symbols "On"
            optimize "On"

        filter "configurations:Release"
            defines { "NC_RELEASE" }
            runtime "Release"
            symbols "Off"
            optimize "Full"
            flags { "NoBufferSecurityCheck", "NoRuntimeChecks" }

        filter "platforms:Win64"
            system "Windows"
            architecture "x86_64"
            defines { "WIN32", "WINDOWS" }

    local isMSVC = BuildSettings:Get("Using MSVC")
    local multithreadedCompilation = BuildSettings:Get("Multithreaded Compilation")
    local multithreadedCoreCount = BuildSettings:Get("Multithreaded Core Count")

    if multithreadedCompilation then
        if isMSVC then
            local cores = multithreadedCoreCount or 0
            if cores > 0 then
                buildoptions { "/MP" .. tostring(cores) }
            else
                buildoptions { "/MP" }
            end
        end
    end
end

function CreateDep(name, callback, dependencies)
    local internalName = "Dependency-" .. name
    if _G[internalName] ~= nil then
        error("Attempted to create dependency '" .. name .. "' but a dependency with the same name already exists")
    end

    print("Creating Dependency '" .. name .. "'")
    _G[internalName] = { }

    if type(callback) ~= "function" then
        error("Attemped to create dependency '" .. name .. "' with the callback parameter passed as a non function")
    end

    _G[internalName].Callback = callback
    _G[internalName].Dependencies = dependencies
end

function AddFiles(list)
    files { list }
end

function AddIncludeDirs(list)
    includedirs { list }
end

function AddLinks(list)
    links { list }
end

function AddDefines(list)
    defines { list }
end

function InitBuildSettings(silentFailOnDuplicateSetting)
    if BuildSettings == nil then
        BuildSettings = { }

        BuildSettings.Has = function(settings, name)
            return settings[name] ~= nil
        end

        BuildSettings.Add = function(settings, name, value)
            local silentFail = settings:ShouldSilentFailOnDuplicateSetting()

            if settings:Has(name) then
                if silentFail then
                    return
                end

                error("Tried to call BuildSettings:Add with name '" .. name .. '" but a setting with that name already exists')
            end

            settings[name] = value
        end

        BuildSettings.Get = function(settings, name)
            if not settings:Has(name) then
                return nil
            end

            return settings[name]
        end

        BuildSettings.SetSilentFailOnDuplicateSetting = function(settings, silentFailOnDuplicateSetting)
            BuildSettings["SilentFailOnDuplicateSetting"] = silentFailOnDuplicateSetting
        end

        BuildSettings.ShouldSilentFailOnDuplicateSetting = function(settings)
            local option = BuildSettings["SilentFailOnDuplicateSetting"]

            if option == nil then
                return false
            end

            return option
        end
    end

    BuildSettings:SetSilentFailOnDuplicateSetting(silentFailOnDuplicateSetting)
end