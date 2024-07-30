function tprint (tbl, indent)
    if not indent then indent = 0 end
    local toprint = string.rep(" ", indent) .. "{\r\n"
    indent = indent + 2 
    for k, v in pairs(tbl) do
      toprint = toprint .. string.rep(" ", indent)
      if (type(k) == "number") then
        toprint = toprint .. "[" .. k .. "] = "
      elseif (type(k) == "string") then
        toprint = toprint  .. k ..  "= "   
      end
      if (type(v) == "number") then
        toprint = toprint .. v .. ",\r\n"
      elseif (type(v) == "string") then
        toprint = toprint .. "\"" .. v .. "\",\r\n"
      elseif (type(v) == "table") then
        toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
      else
        toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
      end
    end
    toprint = toprint .. string.rep(" ", indent-2) .. "}"
    return toprint
  end

function tarray (tbl)
    arr=""
    for k,v in ipairs(tbl) do 
        arr=arr+v
    end
    return arr
end

function tablelength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
  end

function remove_spaces(str)
    str=string.gsub(str, "%s+", "")
    return str
end

function sequence(from,to)
    local i = from - 1
    return function()
      if i < to then
        i = i + 1
        return i
      end
    end
  end

function contains(tbl, key)
    return tbl[key] ~= nil
end

recipeSkillIDs = {}
for i in sequence(400000,500000) do table.insert(recipeSkillIDs,i) end


s = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
s:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
s:RegisterEvent("TRAIT_NODE_CHANGED");
local function eventHandler(self, event, ...)
    print(...)
    outTable=CraftyProfDB or {}
    outTable["RecipeSpellIDs"] = outTable["RecipeSpellIDs"] or {}
    for i, t in pairs(recipeSkillIDs) do
        local recipe = schematic(t)
        if recipe then
            update_row(recipe, t)
            local max_recipe = max_schematic(t)
            if max_recipe then
                update_row(max_recipe, t)
            end
            for _, r in pairs(outTable["RecipeSpellIDs"][t].reagents) do
                local max_single_recipe = test_all_max_schematic(t, r)
                if max_single_recipe then
                    update_row(max_single_recipe, t)
                end
            end
        end
    end
    CraftyProfDB=outTable
end
s:SetScript("OnEvent", eventHandler);
outTable={}

function update_row(row, id)
    if outTable["RecipeSpellIDs"][id] ~= nil then
        outTable["RecipeSpellIDs"][id]["baseDifficulty"] = row["baseDifficulty"]
        outTable["RecipeSpellIDs"][id]["craftingQualityID"] = row["craftingQualityID"]
        if outTable["RecipeSpellIDs"][id]["professionID"] == nil then
            outTable["RecipeSpellIDs"][id]["professionID"] = row["professionID"]
        end
        if outTable["RecipeSpellIDs"][id]["concCosts"] == nil and outTable["RecipeSpellIDs"][id]["craftingQualityID"] > 0 then
            outTable["RecipeSpellIDs"][id]["concCosts"] = {}
        end
        if outTable["RecipeSpellIDs"][id]["craftingQualityID"] > 3 then
            outTable["RecipeSpellIDs"][id]["concCosts"][row["lowerSkill"]] = row["concentrationCost"]
        end
        if row["itemID"] ~= nil then
            if outTable["RecipeSpellIDs"][id]["itemSkill"] == nil then
                outTable["RecipeSpellIDs"][id]["itemSkill"] = {}
            end
            outTable["RecipeSpellIDs"][id]["itemSkill"][row["itemID"]] = row["lowerSkill"]
        end
    else
        outTable["RecipeSpellIDs"][id] = {}
        if outTable["RecipeSpellIDs"][id]["professionID"] == nil then
            outTable["RecipeSpellIDs"][id]["professionID"] = row["professionID"]
        end
        outTable["RecipeSpellIDs"][id]["baseDifficulty"] = row["baseDifficulty"]
        outTable["RecipeSpellIDs"][id]["craftingQualityID"] = row["craftingQualityID"]
        outTable["RecipeSpellIDs"][id]["reagents"] = row["reagents"]
        outTable["RecipeSpellIDs"][id]["name"] = row["name"]
        if outTable["RecipeSpellIDs"][id]["concCosts"] == nil and outTable["RecipeSpellIDs"][id]["craftingQualityID"] > 0 then
            outTable["RecipeSpellIDs"][id]["concCosts"] = {}
        end
        if outTable["RecipeSpellIDs"][id]["craftingQualityID"] > 0 then
            outTable["RecipeSpellIDs"][id]["concCosts"][row["lowerSkill"]] = row["concentrationCost"]
        end
    end
end

function schematic(recipeSkillID)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeSkillID, false)
    if schematic["hasCraftingOperationInfo"] == false then
        return
    end
    local reagentSlotSchematics = schematic["reagentSlotSchematics"]
    local row = {}
    row.name = schematic["name"]
    row.reagents = reagents(reagentSlotSchematics)
    local coi = C_TradeSkillUI.GetCraftingOperationInfo(recipeSkillID, {}, nil, false)
    -- Certain RecipeSpellIDs, such as 47767 Kah, King of the Deeps will claim to have CraftingOperationInfo but actually dont
    if coi ~= nil then
        row["professionID"] = C_TradeSkillUI.GetProfessionInfoByRecipeID(coi["recipeID"])
        -- Crafting quality works this way:
        -- Items with 3 ranks will be between CraftingQualityID 1-3 and difficulty will be 0%, 50%, and 100% of baseDifficulty
        -- Items with 5 ranks will be between CraftingQualityID 4-8 and difficulty will be 0%, 20%, 50%, 80%, and 100% of baseDifficulty
        row["baseDifficulty"] = coi["baseDifficulty"]
        row["craftingQualityID"] = coi["craftingQualityID"]
        row["lowerSkill"] = coi["baseSkill"] + coi["bonusSkill"]
        if coi["craftingQualityID"] > 0 then
            row["concentrationCost"] = coi["concentrationCost"]
        end
    else
        return
    end
    return row
end

function max_schematic(recipeSkillID)
    local row = outTable["RecipeSpellIDs"][recipeSkillID]
    local max_mats = {}
    for _, r in pairs(row.reagents) do
        table.insert(max_mats, {itemID = r.mat_options[#(r.mat_options)], quantity=r.quantityRequired, dataSlotIndex=r.dataSlotIndex})
    end
    -- print(max_mats)
    local max = C_TradeSkillUI.GetCraftingOperationInfo(recipeSkillID, max_mats, nil, false)
    if max ~= nil then
        row["baseDifficulty"] = max["baseDifficulty"]
        row["craftingQualityID"] = max["craftingQualityID"]
        row["lowerSkill"] = max["baseSkill"] + max["bonusSkill"]
        if max["craftingQualityID"] > 0 then
            row["concentrationCost"] = max["concentrationCost"]
        end
    else
        return
    end
    return row
end

function test_all_max_schematic(recipeSkillID, r)
    local row = outTable["RecipeSpellIDs"][recipeSkillID]
    local max = {}
    for _, reagentlist in pairs(outTable["RecipeSpellIDs"][recipeSkillID].reagents) do
        if r.dataSlotIndex == reagentlist.dataSlotIndex then
            table.insert(max, {itemID = r.mat_options[#(r.mat_options)], quantity=r.quantityRequired, dataSlotIndex=r.dataSlotIndex})
        else
            table.insert(max, {itemID = r.mat_options[1], quantity=r.quantityRequired, dataSlotIndex=r.dataSlotIndex})
        end
    end
    local max_single = C_TradeSkillUI.GetCraftingOperationInfo(recipeSkillID, max, nil, false)
    if max_single ~= nil then
        row["baseDifficulty"] = max_single["baseDifficulty"]
        row["craftingQualityID"] = max_single["craftingQualityID"]
        row["lowerSkill"] = max_single["baseSkill"] + max_single["bonusSkill"]
        if max_single["craftingQualityID"] > 0 then
            row["concentrationCost"] = max_single["concentrationCost"]
        end
        row["itemID"] = r.mat_options[#(r.mat_options)]
    else
        return
    end
    return row
end

function reagents(reagentSlotSchematics)
    local re={}
    for i, t in pairs(reagentSlotSchematics) do
        if t.required==true then
            local r={}
            r.quantityRequired = t["quantityRequired"]
            r.dataSlotIndex = t["dataSlotIndex"]
            local mcr={}
            for j, alt in pairs(t.reagents) do
                mcr[j]=alt.itemID
            end
            if #mcr > 0 then
                r.mat_options=mcr
            end
        table.insert(re, r)
        end
    end
    return re
end
--[[
SKILL_LINE_SPECS_RANKS_CHANGED
ProfessionSpecUI 
/script print(C_ProfSpecs.GetTabInfo(2883))
/script print(C_ProfSpecs.GetChildrenForPath(1))
/script print(C_ProfSpecs.GetDefaultSpecSkillLine()) --Most up to date expansion for spec
/script print(C_ProfSpecs.GetCurrencyInfoForSkillLine(2883)) -- Name and number of knowledge points avail
 print(tprint(C_Traits.GetTreeHash(1))) -- returns a hash of 16 values for...
/script for k,v in pairs(C_ProfSpecs.GetChildrenForPath(1)) do print(k..": "..tostring(v)) end
/script for k,v in pairs(C_ProfSpecs.GetChildrenForPath(1)) do print(k) end


--]]
        -- Keeping this after realizing that Difficulty is simple to calculate and only differs based on max Quality rank
        -- This may be a useful jumping off point for automatically identifying reagent weights later
        --[[
        max_mats = {}
        for i, r in ipairs(row.reagents) do
            mat = {}
            -- print("index number: "..#(r.mat_options) .. " for "..recipeSkillID)
            mat["itemID"]=r.mat_options[#(r.mat_options)]
            mat["dataSlotIndex"]=r.dataSlotIndex
            mat["quantity"]=r.quantityRequired
            table.insert(max_mats, mat)
        end
        local max = C_TradeSkillUI.GetCraftingOperationInfo(recipeSkillID, max_mats, nil, false)
        if max ~= nil then
            -- Crafting quality works this way:
            -- Items with 3 ranks will be between CraftingQualityID 1-3
            -- Items with 5 ranks will be between CraftingQualityID 4-8
            qualityID=max["craftingQualityID"]
            if qualityID > 0 then
                local qual = max["craftingQuality"]
                if contains(row,"craftingBaseDifficulty") then
                    row["craftingBaseDifficulty"] = {}
                end
                row["craftingBaseDifficulty"][qual+1]=max["upperSkillTreshold"] --spelling error is in API
                row["craftingBaseDifficulty"][qual]=max["lowerSkillThreshold"]
                if qualityID <= 3 then
                    row["craftingBaseDifficulty"][3]=max["baseDifficulty"]
                else
                    row["craftingBaseDifficulty"][5]=max["baseDifficulty"]
                end
            end
        end
        --]]