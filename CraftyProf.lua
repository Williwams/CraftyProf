local addonName = ...

-- local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture or GetSpellTexture
-- local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) and C_Item.GetItemIconByID or GetItemIconByID
-- local GetItemInfo = (C_Item and C_Item.GetItemInfo) and C_Item.GetItemInfo or GetItemInfo
-- local GetItemGem = (C_Item and C_Item.GetItemGem) and C_Item.GetItemGem or GetItemGem
-- local GetItemSpell = (C_Item and C_Item.GetItemSpell) and C_Item.GetItemSpell or GetItemSpell
-- local GetRecipeReagentItemLink = (C_TradeSkillUI and C_TradeSkillUI.GetRecipeReagentItemLink) and C_TradeSkillUI.GetRecipeReagentItemLink or GetTradeSkillReagentItemLink

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

function updateTextFromTable(table)
    e:SetText(tprint(table))
end
function updateTextFromStr(str)
    e:SetText(str)
end
-- MySimpleHTMLObject = CreateFrame('SimpleHTML',nil,UIParent);
-- MySimpleHTMLObject:SetText('<html><body><h1>Heading1</h1><p>A paragraph</p></body></html>');
-- MySimpleHTMLObject:Show()
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
for i in sequence(441300,448340) do table.insert(recipeSkillIDs,i) end


s = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate") -- or your actual parent instead
s:SetSize(300,200)
s:SetPoint("RIGHT")
e = CreateFrame("EditBox", nil, s)
e:SetAutoFocus(false)
e:SetMultiLine(true)
e:SetFontObject(ChatFontNormal)
e:SetWidth(300)
s:SetScrollChild(e)
--local knownSpells = C_TradeSkillUI.GetBaseProfessionInfo()
--updateTextFromTable(knownSpells)
s:RegisterEvent("TRADE_SKILL_SHOW");
local function eventHandler(self, event, ...)
    -- local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    outTable={}
    outTable["RecipeSpellIDs"] = {}
    for i, t in pairs(recipeSkillIDs) do
        local recipe = schematic(t)
        if recipe then
            outTable["RecipeSpellIDs"][t]=recipe
            --table.insert(outTable,recipe)
        end
    end
    updateTextFromTable(outTable)
    print(tablelength(outTable["RecipeSpellIDs"]))
    -- updateTextFromStr(schematic(445330))
end
s:SetScript("OnEvent", eventHandler);
outTable={}

function schematic(recipeSkillID)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeSkillID, false)
    if schematic["hasCraftingOperationInfo"] == false then
        return
    end
    local reagentSlotSchematics = schematic["reagentSlotSchematics"]
    local row = {}
    row.name = schematic["name"]
    row.reagents = reagents(reagentSlotSchematics)
    sample_mats = {}
    for i, r in pairs(row.reagents) do
        mat = {}
        mat["itemID"]=r.mat_options[1]
        mat["dataSlotIndex"]=r.dataSlotIndex
        mat["quantity"]=r.quantityRequired
        table.insert(sample_mats, mat)
    end
    local coi = C_TradeSkillUI.GetCraftingOperationInfo(recipeSkillID, {}, nil, false)
    -- Certain RecipeSpellIDs, such as 47767 Kah, King of the Deeps will claim to have CraftingOperationInfo but actually dont
    if coi ~= nil then
        -- Crafting quality works this way:
        -- Items with 3 ranks will be between CraftingQualityID 1-3
        -- Items with 5 ranks will be between CraftingQualityID 4-8
        row["craftingQualityID"]=coi["craftingQualityID"]
        row["quality"]=coi["quality"]
    else
        return
    end
    return row
end

function reagents(reagentSlotSchematics)
    re={}
    for i, t in pairs(reagentSlotSchematics) do
        if t.required==true then
            local r={}
            r.quantityRequired = t["quantityRequired"]
            r.dataSlotIndex = t["dataSlotIndex"]
            -- if #t.reagents > 1 then
            local mcr={}
            for j, alt in pairs(t.reagents) do
                mcr[j]=alt.itemID
            end
            if #mcr > 0 then
                --table.insert(r,mcr)
                r["mat_options"]=mcr
            end
         --table.insert(re, t)    
        table.insert(re, r)
        end
    end
    return re
end
