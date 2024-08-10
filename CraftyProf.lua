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
for i in sequence(400000,500000) do table.insert(recipeSkillIDs,i) end


s = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
s:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
s:RegisterEvent("TRAIT_NODE_CHANGED"); -- This may not be necessary, unsure if TRADE_SKILL_LIST_UPDATE fires correctly on close
s:RegisterEvent("CRAFTINGORDERS_UPDATE_ORDER_COUNT");
--s:RegisterEvent("AUCTION_HOUSE_SHOW"); 
--s:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE");
s:RegisterEvent("TRADE_SKILL_SHOW");
s:RegisterEvent("TRADE_SKILL_LIST_UPDATE");
local function eventHandler(self, event, ...)
    charTable=CraftyProfCharacterDB or {}
    outTable=CraftyProfDB or {}
    outTable["RecipeSpellIDs"] = outTable["RecipeSpellIDs"] or {}
    outTable["items"] = outTable["items"] or {}
    charTable["CraftingOrders"] = charTable["CraftingOrders"] or {}
    charTable["ProfTraits"] = charTable["ProfTraits"] or {}
    charTable["RecipeList"] = charTable["RecipeList"] or {}
    outTable["auctions"] = outTable["auctions"] or {}
    if event == "CRAFTINGORDERS_UPDATE_ORDER_COUNT" then
        orderTab, orderNum = ...
        orders = C_CraftingOrders.GetCrafterOrders(orderTab)
        for i, coi in pairs(orders) do
            info = getCraftingOrderInfo(coi)
            charTable["CraftingOrders"][coi.orderID] = info
        end
    end
    --if event == "AUCTION_HOUSE_SHOW" then
        --outTable["auctions"] = getAllAuctions()
    --end
    if event == "ADDON_LOADED" then
        -- Do Profession Traits on login, should also do after its been updated
        local nodeData=map_profession_traits()
        charTable["ProfTraits"] = nodeData
        
        -- This needs to be refactored and then split in to its own addon. 
        -- This functionality is only used to scrape in game resources for crafting data
        for i, t in pairs(recipeSkillIDs) do
            local recipe = schematic(t)
            if recipe then
                outTable["RecipeSpellIDs"][t] = recipe
            end
        end
    end
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        prof, data = update_recipe_list("Khaz Algar") 
        if prof > 0 then
            charTable["RecipeList"][prof] = data
        end
    end
    CraftyProfCharacterDB = charTable
    CraftyProfDB=outTable
end
s:SetScript("OnEvent", eventHandler);

function get_concentration_cap_timestamp(professionID)
    local currencyID = C_TradeSkillUI.GetConcentrationCurrencyID(professionID)
    local concentrationInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    local curTime = C_DateAndTime.GetServerTimeLocal()
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
    local reagentSlotSchematics = schematic["reagentSlotSchematics"]
    local row = {}
    row.name = schematic["name"]
    row.reagents = reagents(reagentSlotSchematics)
    local coi = C_TradeSkillUI.GetCraftingOperationInfo(recipeSkillID, {}, nil, false)
    if coi ~= nil then
        row["professionID"] = C_TradeSkillUI.GetProfessionInfoByRecipeID(coi["recipeID"])
        -- Crafting quality works this way:
        -- Items with 3 ranks will be between CraftingQualityID 1-3 and difficulty will be 0%, 50%, and 100% of baseDifficulty
        -- Items with 5 ranks will be between CraftingQualityID 4-8 and difficulty will be 0%, 20%, 50%, 80%, and 100% of baseDifficulty
        row["baseDifficulty"] = coi["baseDifficulty"]
        row["craftingQualityID"] = coi["craftingQualityID"]
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

function getAllAuctions()
    
    ah_list=C_AuctionHouse.ReplicateItems()
    ah_length=C_AuctionHouse.GetNumReplicateItems()
    print("Starting to collect" .. ah_length .. "auctions, please wait")
    local i=0
    local db_out = {}
    while i< ah_length do
        local info = { C_AuctionHouse.GetReplicateItemInfo(i) }
        local link = C_AuctionHouse.GetReplicateItemLink(i)
        if not C_Item.DoesItemExistByID(info[17]) then
            --Continue would go here if it could
        else
            db_out[i]={info, link}
        end
        if i % 10000 then
            print("finished ".. i .. " out of " .. ah_length)
        end
        i = i + 1
    end
    return db_out
end

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
