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

function updateTextFromTable(table)
    e:SetText(tprint(table))
end
function updateTextFromStr(str)
    e:SetText(str)
end
-- MySimpleHTMLObject = CreateFrame('SimpleHTML',nil,UIParent);
-- MySimpleHTMLObject:SetText('<html><body><h1>Heading1</h1><p>A paragraph</p></body></html>');
-- MySimpleHTMLObject:Show()


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
    table.insert(outTable,schematic(445330))
    updateTextFromTable(outTable)
    -- updateTextFromStr(schematic(445330))
end
s:SetScript("OnEvent", eventHandler);
outTable={}



function schematic(recipeSkillID)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeSkillID, false)
    local recipeID = schematic["recipeID"]
    local name = schematic["name"]
    local reagentSlotSchematics = schematic["reagentSlotSchematics"]
    local row = {}
    row.name = name
    row.recipeID = recipeID
    row.reagents = reagents(reagentSlotSchematics)
    -- updateTextFromTable(schematic)
    -- return recipeID..": "..name
    return row -- reagents(reagentSlotSchematics)
end

function reagents(reagentSlotSchematics)
    re={}
    for i, t in pairs(reagentSlotSchematics) do
        r={}
        r.required = t.required
        r.reagents = t.reagents[1]["itemID"]
        table.insert(re, r)
    end
    return re
end
