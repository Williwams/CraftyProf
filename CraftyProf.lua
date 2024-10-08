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
    print(toprint)
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


recipeSkillIDs = {}


SLASH_CRAFTYSCRAPE1 = "/craftyscrape"
SlashCmdList["CRAFTYSCRAPE"] = function()
    scrape_recipe_reagents()
 end 
s = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
s:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
s:RegisterEvent("TRAIT_NODE_CHANGED"); -- This may not be necessary, unsure if TRADE_SKILL_LIST_UPDATE fires correctly on close
s:RegisterEvent("CRAFTINGORDERS_UPDATE_ORDER_COUNT");
--s:RegisterEvent("AUCTION_HOUSE_SHOW"); 
--s:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE");
s:RegisterEvent("TRADE_SKILL_SHOW");
s:RegisterEvent("TRADE_SKILL_LIST_UPDATE");
s:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT");
s:RegisterEvent("TRADE_SKILL_CURRENCY_REWARD_RESULT");
s:RegisterEvent("TRADE_SKILL_CRAFT_BEGIN");
cur_recipe = ""
cur_material = 0
local function eventHandler(self, event, ...)
    if event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" or event == "TRADE_SKILL_CURRENCY_REWARD_RESULT" then
        resultData = ...
        out = CraftyProfCraftingDB or {}
        profInfo = C_TradeSkillUI.GetChildProfessionInfo()
        stats = getProfessionItemStats()
        resultData["baseSkill"] = profInfo["baseSkill"]
        resultData["RecipeSpellID"] = cur_recipe
        resultData["material_itemID"] = cur_material
        resultData["ProfStats"] = stats
        traits = getRelevantProfTraits(profInfo.professionID, CraftyProfCharacterDB["ProfTraits"])
        resultData["ProfTraits"] = traits
        table.insert(out, resultData)
        CraftyProfCraftingDB = out
    else
        charTable=CraftyProfCharacterDB or {}
        charTable["CraftingOrders"] = charTable["CraftingOrders"] or {}
        charTable["ProfTraits"] = charTable["ProfTraits"] or {}
        charTable["RecipeList"] = charTable["RecipeList"] or {}
        if event == "CRAFTINGORDERS_UPDATE_ORDER_COUNT" then
            orderTab, orderNum = ...
            orders = C_CraftingOrders.GetCrafterOrders(orderTab)
            for _, coi in pairs(orders) do
                info = getCraftingOrderInfo(coi)
                charTable["CraftingOrders"][coi.orderID] = info
            end
        end
        --if event == "AUCTION_HOUSE_SHOW" then
            --outTable["auctions"] = getAllAuctions()
        --end
        if event == "ADDON_LOADED" then
            hookstuff()
            -- Just blast away the Crafting output database so it doesnt get out of hand. this should be imported
            -- quickly by Taskmaster and before a second refresh happens. If not, its just crafting output metrics
            -- so its not critical
            CraftyProfCraftingDB = {}
            -- Do Profession Traits on login, should also do after its been updated
            local nodeData=map_profession_traits()
            charTable["ProfTraits"] = nodeData
            charTable["charGUID"] = UnitGUID("player")
            -- This needs to be refactored and then split in to its own addon. 
            -- This functionality is only used to scrape in game resources for crafting data
        end
        if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
            prof, data = update_recipe_list("Khaz Algar") 
            if prof > 0 then
                charTable["RecipeList"][prof] = data
            end
        end
        CraftyProfCharacterDB = charTable
    end
end
s:SetScript("OnEvent", eventHandler);


function hookstuff()
    hooksecurefunc(C_TradeSkillUI, "CraftSalvage", catch_salvage)
end

-- Salvage is the Tradeskill type used by Prospecting and Milling and is the only way to actually determine what is being done
-- You can infer RecipeSpellID from clicking around in the UI but this the only way to extract what material you are using without
-- relying on Resourcefulness procs
function catch_salvage(recipeSpellID, numCasts, itemTarget, craftingReagents, applyConcentration)    
    cur_recipe = recipeSpellID
    cur_material = C_Container.GetContainerItemID(itemTarget["bagID"], itemTarget["slotIndex"])
end
function getRelevantProfTraits(prof, full_list)
    outlist = {}
    for node, count in pairs(full_list) do
        for _, entry in ipairs(TraitNodes[prof]) do
            if entry == node then
                outlist[node] = count
            end
        end
    end
    return outlist
end

function scrape_recipe_reagents()
    for i in sequence(300000,550000) do table.insert(recipeSkillIDs,i) end
    outTable = outTable or {}
    outTable["RecipeSpellIDs"] = {}
    for _, t in pairs(recipeSkillIDs) do
        local recipe = schematic(t)
        if recipe then
            outTable["RecipeSpellIDs"][t] = recipe
        end
    end
    CraftyProfDB=outTable
end

function get_concentration_cap_timestamp(professionID)
    local currencyID = C_TradeSkillUI.GetConcentrationCurrencyID(professionID)
    local concentrationInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    local curTime = time()
    local remaining_ticks = (concentrationInfo.maxQuantity - concentrationInfo.quantity)/concentrationInfo.rechargingAmountPerCycle
    return curTime + concentrationInfo.rechargingCycleDurationMS * remaining_ticks / 1000
end

function update_recipe_list(expansionName)
    local profInfo = C_TradeSkillUI.GetChildProfessionInfo()
    local row = {}
    local professionID = profInfo.professionID
    if profInfo.expansionName == expansionName then
        row.skillLevel=profInfo.skillLevel -- Base skill for this top
        row.skillModifier=profInfo.skillModifier --Additional points from gear and racials
        row.maxSkill=profInfo.maxSkill -- Max skill. Usually 100 but this might run against an older skill or Fishing
        row.ConcentrationFill = get_concentration_cap_timestamp(professionID) -- Timestamp when Concentration will be refilled. More stable to store and use this way
    end
    row.ProfessionStats=getProfessionItemStats()
    row.Recipes={}
    for _, id in pairs(C_TradeSkillUI.GetAllRecipeIDs()) do
        local recipeInfo = C_TradeSkillUI.GetRecipeInfo(id)
        if recipeInfo.learned then
            table.insert(row.Recipes,recipeInfo.recipeID)
        end
    end
    return tonumber(professionID), row

end

-- print(C_TradeSkillUI.GetBaseProfessionInfo()["profession"]) gives 7 for tailoring
-- print(C_TradeSkillUI.IsNearProfessionSpellFocus(7)) true if near table
-- C_TradeSkillUI.OpenRecipe(446930)
function map_profession_traits()
    local nodeMap = {}
    for prof, nodelist in pairs(TraitNodes) do
        local configID = C_ProfSpecs.GetConfigIDForSkillLine(prof)
        if configID > 0 then
            for _, node in pairs(TraitNodes[prof]) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, node)
                if nodeInfo.activeEntry.rank > 0 then
                    nodeMap[node]=nodeInfo.activeEntry.rank
                end
            end
        end
    end
    return nodeMap
end

function schematic(recipeSkillID)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeSkillID, false)
    if schematic["hasCraftingOperationInfo"] == false then
        return
    end
    local row = {}
    local coi = C_TradeSkillUI.GetCraftingOperationInfo(recipeSkillID, {}, nil, false)
    if coi ~= nil then
        row["professionID"] = C_TradeSkillUI.GetProfessionInfoByRecipeID(coi["recipeID"])
        row.reagents = reagents(schematic["reagentSlotSchematics"])
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

function getProfessionItemStats()
    local profInfo = C_TradeSkillUI.GetChildProfessionInfo()
    local gearSlots = C_TradeSkillUI.GetProfessionSlots(profInfo.profession)
    local statSums = {["Multicraft"] = 0, ["Crafting Speed"] = 0, ["Resourcefulness"] = 0, ["Ingenuity"] = 0}
    for _, slot in pairs(gearSlots) do
        local itemLink = GetInventoryItemLink("player",slot)
        if itemLink ~= nil then
            local stats = C_Item.GetItemStats(itemLink)
            for stat, amt in pairs(stats) do
                statSums[statShorts[stat]] = statSums[statShorts[stat]] + tonumber(amt)
            end
            
            local amount, enchant_stat = readEnchant(itemLink)
            if amount > 0 and statSums[enchant_stat] ~= nil then
                statSums[enchant_stat] = statSums[enchant_stat] + tonumber(amount)
            end
        end
    end
    return statSums
end

statShorts = {
    ["ITEM_MOD_MULTICRAFT_SHORT"] = "Multicraft",
    ["ITEM_MOD_CRAFTING_SPEED_SHORT"] = "Crafting Speed",
    ["ITEM_MOD_RESOURCEFULNESS_SHORT"] = "Resourcefulness",
    ["ITEM_MOD_INGENUITY_SHORT"] = "Ingenuity",

}


function readEnchant(itemLink)
    local tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
    for _, line in pairs(tooltipData.lines) do
        if string.find(line.leftText, 'Enchanted:') then
            -- split capture groups to pass it back
            local amount, stat = string.match(line.leftText, "Enchanted: [+](%d+) (%w+)")
            return tonumber(amount), stat
        end
    end
    return 0, 0
end

-- function getAllAuctions()
    
--     ah_list=C_AuctionHouse.ReplicateItems()
--     ah_length=C_AuctionHouse.GetNumReplicateItems()
--     print("Starting to collect" .. ah_length .. "auctions, please wait")
--     local i=0
--     local db_out = {}
--     while i< ah_length do
--         local info = { C_AuctionHouse.GetReplicateItemInfo(i) }
--         local link = C_AuctionHouse.GetReplicateItemLink(i)
--         if not C_Item.DoesItemExistByID(info[17]) then
--             --Continue would go here if it could
--         else
--             db_out[i]={info, link}
--         end
--         if i % 10000 then
--             print("finished ".. i .. " out of " .. ah_length)
--         end
--         i = i + 1
--     end
--     return db_out
-- end

function getCraftingOrderInfo(coi)
    row = {}
    row["itemID"] = coi["itemID"]
    row["spellID"] = coi["spellID"]
    row["minQuality"] = coi["minQuality"]
    row["reagentState"] = coi["reagentState"]
    row["netTip"] = coi["tipAmount"] - coi["consortiumCut"]
    row["npcOrderRewards"] = row["npcOrderRewards"] or {}
    for _, r in pairs(coi["npcOrderRewards"]) do
        if r['itemLink'] ~= nil then
            local l = r['itemLink']
            -- lua regex doesnt support limiting quantifiers so we have to just tell it we want 6 numbers in a row
            for i in string.gmatch(l, "[0-9][0-9][0-9][0-9][0-9][0-9]") do
                row["npcOrderRewards"]["itemID"] = i
            end
        end
        if r['currencyType'] ~= nil then
            row["npcOrderRewards"]["currencyType"] = r['currencyType']
        end
        row["npcOrderRewards"]["count"] = r['count']
    end
    row["suppliedReagents"] = row["suppliedReagents"] or {}
    for _, r in pairs(coi["reagents"]) do
        if r["source"] == 1 then
            row["suppliedReagents"][r['reagent']['itemID']] = r['source']
        end
    end
    return row
end
