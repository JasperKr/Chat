local privileges = {
    0, -- 0 - no privileges
    1, -- 1 - default user
    2, -- 2 - moderator
    3, -- 3 - admin
}

local function hasPrivileges(userID, requiredPrivilege)
    local user = UserService.get(userID)
    if not user then
        return false, "User not found"
    end

    if user.privelege >= requiredPrivilege then
        return true
    else
        return false, "Insufficient privileges"
    end
end

return {
    privileges = privileges,
    hasPrivileges = hasPrivileges,
}
