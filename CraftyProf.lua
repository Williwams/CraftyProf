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
    outTable["items"] = outTable["items"] or {}
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

-- C_Traits.GetStagedChanges(configID)
-- C_Traits.GetNodeInfo(configID, nodeID)
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
        --if row["craftingDataItemIDs"] == nil then
            row["craftingDataItemIDs"] = {}
        --end
        row["craftingDataItemIDs"][coi["craftingQualityID"]] = getItemIDByCraftingDataID(coi["craftingDataID"])
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
        if row["craftingDataItemIDs"] == nil then
            row["craftingDataItemIDs"] = {}
        end
        row["craftingDataItemIDs"][max["craftingQualityID"]] = getItemIDByCraftingDataID(max["craftingDataID"])
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
        if row["craftingDataItemIDs"] == nil then
            row["craftingDataItemIDs"] = {}
        end
        row["craftingDataItemIDs"][max_single["craftingQualityID"]] = getItemIDByCraftingDataID(max_single["craftingDataID"])
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

function getItemIDByCraftingDataID(craftingDataID)
    return tonumber(craftingData[craftingDataID]) or craftingDataID
end

-- This data comes from the table CraftingDataItemQuality which can be searched per craftingDataID
-- It should be ordered such that CraftingQualityID can be used as an index of the rows matching craftingDataID
function getItemIDByCraftingDataItemQualityID(craftingDataID, craftingQualityID)
    return tonumber(craftingDataItemQuality[craftingDataID][craftingDataID]) or 0
end

craftingData = 
    {
    [1675] = "222715",
    [1676] = "222716",
    [1677] = "222717",
    [1678] = "222718",
    [1679] = "222719",
    [1680] = "222720",
    [1681] = "222721",
    [1682] = "222722",
    [1683] = "222723",
    [1684] = "222724",
    [1685] = "222725",
    [1686] = "222726",
    [1687] = "222727",
    [1688] = "222728",
    [1689] = "222729",
    [1690] = "222730",
    [1691] = "222731",
    [1692] = "222732",
    [1693] = "222733",
    [1695] = "222735",
    [1696] = "222736",
    [1700] = "220420",
    [1701] = "220421",
    [1702] = "220422",
    [1703] = "220423",
    [1706] = "220426",
    [1707] = "220427",
    [1709] = "222742",
    [1710] = "222743",
    [1711] = "222744",
    [1712] = "222745",
    [1714] = "222747",
    [1715] = "222748",
    [1716] = "222749",
    [1797] = "221801",
    [1798] = "221802",
    [1799] = "221803",
    [1800] = "221804",
    [1801] = "221805",
    [1802] = "221806",
    [1803] = "221807",
    [1804] = "221808",
    [1805] = "221786",
    [1806] = "221787",
    [1807] = "221788",
    [1808] = "221789",
    [1809] = "221790",
    [1810] = "221791",
    [1811] = "221792",
    [1812] = "221793",
    [1813] = "221795",
    [1814] = "221796",
    [1815] = "221797",
    [1816] = "221798",
    [1817] = "221799",
    [1818] = "221800",
    [1835] = "221969",
    [1847] = "221945",
    [1848] = "221949",
    [1850] = "221957",
    [1851] = "221959",
    [1852] = "219387",
    [1853] = "221962",
    [1854] = "221964",
    [1855] = "221966",
    [1856] = "221967",
    [2140] = "222429",
    [2141] = "222430",
    [2142] = "222431",
    [2143] = "222432",
    [2144] = "222433",
    [2145] = "222434",
    [2146] = "222435",
    [2147] = "222436",
    [2148] = "222437",
    [2149] = "222438",
    [2150] = "222439",
    [2151] = "222440",
    [2152] = "222441",
    [2153] = "222442",
    [2154] = "222443",
    [2155] = "222444",
    [2156] = "222445",
    [2157] = "222446",
    [2158] = "222447",
    [2159] = "222448",
    [2160] = "222449",
    [2161] = "222450",
    [2162] = "222451",
    [2165] = "222458",
    [2166] = "222459",
    [2170] = "222463",
    [2171] = "222464",
    [2172] = "222465",
    [2173] = "222466",
    [2174] = "222467",
    [2175] = "222468",
    [2176] = "222469",
    [2177] = "222470",
    [2178] = "222471",
    [2179] = "222472",
    [2180] = "222473",
    [2181] = "222474",
    [2182] = "222475",
    [2183] = "222476",
    [2184] = "222477",
    [2185] = "222478",
    [2186] = "222479",
    [2187] = "222480",
    [2188] = "222481",
    [2189] = "222482",
    [2190] = "222483",
    [2191] = "222484",
    [2192] = "222485",
    [2193] = "222486",
    [2194] = "222487",
    [2195] = "222488",
    [2196] = "222489",
    [2197] = "222490",
    [2198] = "222491",
    [2199] = "222492",
    [2200] = "222493",
    [2201] = "222494",
    [2202] = "222495",
    [2203] = "225660",
    [2211] = "222520",
    [2212] = "222523",
    [2230] = "225855",
    [2233] = "222546",
    [2234] = "222547",
    [2235] = "222548",
    [2236] = "222549",
    [2237] = "222550",
    [2238] = "222551",
    [2239] = "222552",
    [2240] = "222553",
    [2241] = "222554",
    [2248] = "222565",
    [2249] = "222566",
    [2250] = "222567",
    [2251] = "222568",
    [2252] = "222569",
    [2253] = "222570",
    [2256] = "222573",
    [2257] = "222574",
    [2258] = "222575",
    [2259] = "222576",
    [2260] = "222577",
    [2261] = "222578",
    [2274] = "222621",
    [2286] = "222649",
    [2288] = "222651",
    [2342] = "222807",
    [2343] = "222808",
    [2344] = "222809",
    [2345] = "222810",
    [2346] = "222811",
    [2347] = "222812",
    [2349] = "222814",
    [2350] = "222815",
    [2351] = "222816",
    [2352] = "222817",
    [2353] = "222818",
    [2354] = "222819",
    [2355] = "222820",
    [2356] = "222821",
    [2357] = "222822",
    [2367] = "222832",
    [2368] = "222833",
    [2369] = "222834",
    [2370] = "222835",
    [2371] = "222836",
    [2372] = "222837",
    [2373] = "222838",
    [2374] = "222839",
    [2375] = "222840",
    [2376] = "222841",
    [2377] = "222842",
    [2378] = "222843",
    [2379] = "222844",
    [2380] = "222845",
    [2381] = "222846",
    [2382] = "222847",
    [2383] = "222848",
    [2384] = "222849",
    [2385] = "222850",
    [2386] = "222851",
    [2387] = "222852",
    [2388] = "222853",
    [2389] = "222854",
    [2390] = "222855",
    [2391] = "222856",
    [2392] = "222857",
    [2393] = "222858",
    [2394] = "222859",
    [2395] = "222860",
    [2396] = "222861",
    [2397] = "222862",
    [2398] = "222863",
    [2399] = "222864",
    [2400] = "222865",
    [2401] = "222866",
    [2402] = "222867",
    [2421] = "223968",
    [2422] = "223969",
    [2423] = "223970",
    [2424] = "223971",
    [2426] = "224765",
    [2428] = "224852",
    [2429] = "225366",
    [2430] = "225367",
    [2431] = "225371",
    [2432] = "225373",
    [2433] = "225374",
    [2434] = "225375",
    [2435] = "225376",
    [2436] = "225377",
    [2437] = "225370",
    [2438] = "225372",
    [2439] = "225368",
    [2440] = "225369",
    [2441] = "225592",
    [2442] = "225642",
    [2443] = "225643",
    [2444] = "225644",
    [2445] = "225645",
    [2446] = "225646",
    [2450] = "225884",
    [2452] = "225729",
    [2453] = "225936"
}

CraftingDataItemQuality = 
{
    ["1"] = {"190645","190643","190642"},
    ["2"] = {"189541","189542","189543"},
    ["7"] = {"190531","190530","190532"},
    ["8"] = {"204995","204996","204994"},
    ["9"] = {"190536","190537","190538"},
    ["14"] = {"191318","191319","191320"},
    ["31"] = {"191321","191322","191323"},
    ["58"] = {"191324","191325","191326"},
    ["63"] = {"191327","191328","191329"},
    ["64"] = {"191330","191331","191332"},
    ["65"] = {"191333","191334","191335"},
    ["66"] = {"191336","191337","191338"},
    ["71"] = {"191339","191340","191341"},
    ["74"] = {"191342","191343","191344"},
    ["75"] = {"191345","191346","191347"},
    ["76"] = {"191348","191349","191350"},
    ["77"] = {"191351","191352","191353"},
    ["78"] = {"191354","191355","191356"},
    ["80"] = {"191357","191358","191359"},
    ["82"] = {"191360","191361","191362"},
    ["83"] = {"191363","191364","191365"},
    ["84"] = {"191366","191367","191368"},
    ["85"] = {"191369","191370","191371"},
    ["86"] = {"191372","191373","191374"},
    ["87"] = {"191375","191376","191377"},
    ["88"] = {"191378","191379","191380"},
    ["89"] = {"191381","191382","191383"},
    ["90"] = {"191384","191385","191386"},
    ["91"] = {"191387","191388","191389"},
    ["93"] = {"191393","191394","191395"},
    ["94"] = {"191396","191397","191398"},
    ["95"] = {"191399","191400","191401"},
    ["97"] = {"191482","191483","191484"},
    ["98"] = {"191485","191486","191487"},
    ["99"] = {"191488","191489","191490"},
    ["101"] = {"191493","191494","191495"},
    ["102"] = {"191496","191497","191498"},
    ["103"] = {"191499","191500","191501"},
    ["104"] = {"191502","191503","191504"},
    ["105"] = {"191505","191506","191507"},
    ["106"] = {"191508","191509","191510"},
    ["107"] = {"191511","191512","191513"},
    ["108"] = {"191514","191515","191516"},
    ["109"] = {"191517","191518","191519"},
    ["110"] = {"191520","191521","191522"},
    ["111"] = {"191523","191524","191525"},
    ["114"] = {"191532","191533","191534"},
    ["115"] = {"191535","191536","191537"},
    ["132"] = {"191250","191872","191873"},
    ["133"] = {"191252","191874","191875"},
    ["155"] = {"191261","191884","191885"},
    ["195"] = {"191933","191939","191940"},
    ["196"] = {"191943","191944","191945"},
    ["197"] = {"191950","191949","191948"},
    ["198"] = {"191948","191949","191950"},
    ["214"] = {"192900","192901","192902"},
    ["215"] = {"192903","192904","192905"},
    ["216"] = {"192906","192907","192908"},
    ["217"] = {"192910","192911","192912"},
    ["218"] = {"192913","192914","192916"},
    ["219"] = {"192917","192918","192919"},
    ["220"] = {"192920","192921","192922"},
    ["221"] = {"192923","192924","192925"},
    ["222"] = {"192926","192927","192928"},
    ["223"] = {"192929","192931","192932"},
    ["224"] = {"192933","192934","192935"},
    ["225"] = {"192936","192937","192938"},
    ["226"] = {"192940","192941","192942"},
    ["227"] = {"192943","192944","192945"},
    ["228"] = {"192946","192947","192948"},
    ["229"] = {"192950","192951","192952"},
    ["230"] = {"192953","192954","192955"},
    ["231"] = {"192956","192957","192958"},
    ["232"] = {"192959","192960","192961"},
    ["233"] = {"192962","192963","192964"},
    ["234"] = {"192965","192966","192967"},
    ["235"] = {"192968","192969","192970"},
    ["236"] = {"192971","192972","192973"},
    ["237"] = {"192974","192975","192976"},
    ["238"] = {"192977","192978","192979"},
    ["239"] = {"192980","192981","192982"},
    ["240"] = {"192983","192984","192985"},
    ["241"] = {"192986","192987","192988"},
    ["242"] = {"192989","192990","192991"},
    ["243"] = {"192992","192993","192994"},
    ["245"] = {"192834","192835","192836"},
    ["246"] = {"191474","191475","191476"},
    ["247"] = {"192876","192877","192878"},
    ["248"] = {"192883","192884","192885"},
    ["249"] = {"192894","192895","192896"},
    ["250"] = {"192897","192898","192899"},
    ["262"] = {"193007","193008","193009"},
    ["263"] = {"193011","193012","193013"},
    ["264"] = {"193015","193016","193017"},
    ["265"] = {"193019","193020","193021"},
    ["271"] = {"193029","193030","193031"},
    ["289"] = {"192887","193378","193379"},
    ["298"] = {"193469","193552","193555"},
    ["300"] = {"193236","193237","193238"},
    ["301"] = {"193248","193249","193250"},
    ["305"] = {"193232","193233","193234"},
    ["307"] = {"193239","193240","193241"},
    ["308"] = {"193242","193243","193244"},
    ["311"] = {"193468","193551","193554"},
    ["314"] = {"193245","193246","193247"},
    ["315"] = {"193556","193560","193564"},
    ["347"] = {"193229","193230","193231"},
    ["359"] = {"193559","193563","193567"},
    ["378"] = {"193226","193227","193228"},
    ["381"] = {"193557","193561","193565"},
    ["458"] = {"193950","193951","193952"},
    ["459"] = {"193938","193939","193940"},
    ["461"] = {"193956","193957","193958"},
    ["462"] = {"193932","193933","193934"},
    ["463"] = {"193944","193945","193946"},
    ["464"] = {"193941","193942","193943"},
    ["465"] = {"193935","193936","193937"},
    ["470"] = {"194042","194043","194044"},
    ["471"] = {"194045","194046","194047"},
    ["474"] = {"194011","194012","194013"},
    ["475"] = {"193962","193963","193964"},
    ["477"] = {"194014","194015","194016"},
    ["479"] = {"193959","193960","193961"},
    ["480"] = {"193953","193954","193955"},
    ["481"] = {"194008","194009","194010"},
    ["482"] = {"193929","193930","193931"},
    ["484"] = {"194048","194049","194050"},
    ["485"] = {"193926","193927","193928"},
    ["490"] = {"194112","194113","194114"},
    ["496"] = {"194723","194724","194725"},
    ["502"] = {"197720","197721","197722"},
    ["499"] = {"198084","198151","194714"},
    ["563"] = {"198278","198279","198280"},
    ["564"] = {"198292","198293","198294"},
    ["565"] = {"198295","198296","198297"},
    ["566"] = {"198313","198314","198315"},
    ["567"] = {"198316","198317","198318"},
    ["568"] = {"198275","198276","198277"},
    ["570"] = {"198239","198240","198241"},
    ["571"] = {"198180","198181","198182"},
    ["572"] = {"198281","198282","198283"},
    ["573"] = {"198289","198290","198291"},
    ["575"] = {"198271","198272","198273"},
    ["580"] = {"198228","198229","198230"},
    ["581"] = {"198304","198305","198306"},
    ["582"] = {"198201","198202","198203"},
    ["583"] = {"198259","198260","198261"},
    ["584"] = {"198253","198254","198255"},
    ["585"] = {"198256","198257","198258"},
    ["586"] = {"198183","198184","198185"},
    ["587"] = {"198216","198217","198218"},
    ["588"] = {"198219","198220","198221"},
    ["590"] = {"198157","198158","198159"},
    ["591"] = {"198166","198167","198168"},
    ["592"] = {"198207","198208","198209"},
    ["593"] = {"198213","198214","198215"},
    ["594"] = {"198210","198211","198212"},
    ["595"] = {"198169","198170","198171"},
    ["596"] = {"198301","198302","198303"},
    ["597"] = {"198177","198178","198179"},
    ["598"] = {"198186","198187","198188"},
    ["599"] = {"198189","198190","198191"},
    ["600"] = {"198192","198193","198194"},
    ["601"] = {"198195","198196","198197"},
    ["602"] = {"198198","198199","198200"},
    ["604"] = {"198174","198175","198176"},
    ["605"] = {"198231","198232","198233"},
    ["606"] = {"198236","198237","198238"},
    ["607"] = {"198307","198308","198309"},
    ["608"] = {"198160","198161","198162"},
    ["609"] = {"198163","198164","198165"},
    ["629"] = {"198298","198299","198300"},
    ["630"] = {"198310","198311","198312"},
    ["631"] = {"198250","198251","198252"},
    ["636"] = {"194751","194752","194846"},
    ["643"] = {"194856","194857","194858"},
    ["644"] = {"194850","194758","194852"},
    ["645"] = {"194760","194761","194855"},
    ["646"] = {"194754","194755","194756"},
    ["657"] = {"194570","194571","194569"},
    ["658"] = {"192553","192554","192552"},
    ["659"] = {"194567","194568","194566"},
    ["660"] = {"194573","194574","194572"},
    ["661"] = {"194576","194577","194575"},
    ["662"] = {"194579","194580","194578"},
    ["663"] = {"194821","194822","194823"},
    ["664"] = {"194817","194819","194820"},
    ["665"] = {"194824","194825","194826"},
    ["667"] = {"194862","194863","194864"},
    ["668"] = {"194859","194767","194768"},
    ["681"] = {"198491","198492","198493"},
    ["692"] = {"198494","198495","198496"},
    ["693"] = {"198497","198498","198499"},
    ["694"] = {"198500","198501","198502"},
    ["695"] = {"198503","198504","198505"},
    ["696"] = {"198506","198507","198508"},
    ["544"] = {"197718","198616","198617"},
    ["712"] = {"198619","198620","198621"},
    ["669"] = {"199052","194871","199051"},
    ["670"] = {"199054","194870","199053"},
    ["671"] = {"194869","199059","199060"},
    ["672"] = {"199056","194868","199055"},
    ["673"] = {"198431","199057","199058"},
    ["721"] = {"199188","199189","199190"},
    ["722"] = {"199193","199194","199195"},
    ["775"] = {"198534","198535","198536"},
    ["776"] = {"200565","200566","200567"},
    ["777"] = {"200568","200569","200570"},
    ["778"] = {"200571","200572","200573"},
    ["779"] = {"200574","200575","200576"},
    ["780"] = {"200577","200578","200579"},
    ["781"] = {"200580","200581","200582"},
    ["785"] = {"200618","200633","200634"},
    ["831"] = {"201407","201408","201409"},
    ["283"] = {"192888","202048","202054"},
    ["284"] = {"192889","202049","202055"},
    ["285"] = {"192890","202050","202056"},
    ["286"] = {"192891","202051","202057"},
    ["287"] = {"192892","202052","202058"},
    ["996"] = {"204238","204679","204680"},
    ["998"] = {"204700","204701","204702"},
    ["1001"] = {"204708","204709","204710"},
    ["1004"] = {"204823","204825","204826"},
    ["1005"] = {"204827","204828","204829"},
    ["1011"] = {"205014","205015","205016"},
    ["1018"] = {"204858","204859","204860"},
    ["1019"] = {"204971","204972","204973"},
    ["1020"] = {"204993","204991","204992"},
    ["1021"] = {"205007","205006","205005"},
    ["1032"] = {"205043","205044","205039"},
    ["1033"] = {"204909","205115","205170"},
    ["1034"] = {"205171","205172","205173"},
    ["1035"] = {"190533","190534","190535"},
    ["1055"] = {"207021","207022","207023"},
    ["1056"] = {"207039","207040","207041"},
    ["1061"] = {"208187","208188","208189"},
    ["1104"] = {"208746","208747","208748"},
    ["1110"] = {"210244","210245","210246"},
    ["1111"] = {"210247","210248","210249"},
    ["1117"] = {"210671","210672","210673"},
    ["1171"] = {"211878","211879","211880"},
    ["1173"] = {"212239","212240","212241"},
    ["1174"] = {"212242","212243","212244"},
    ["1175"] = {"212245","212246","212247"},
    ["1176"] = {"212248","212249","212250"},
    ["1177"] = {"212251","212252","212253"},
    ["1178"] = {"212254","212255","212256"},
    ["1179"] = {"212257","212258","212259"},
    ["1180"] = {"212260","212261","212262"},
    ["1181"] = {"212263","212264","212265"},
    ["1182"] = {"212266","212267","212268"},
    ["1183"] = {"212269","212270","212271"},
    ["1184"] = {"212272","212273","212274"},
    ["1185"] = {"212275","212276","212277"},
    ["1186"] = {"212278","212279","212280"},
    ["1187"] = {"212281","212282","212283"},
    ["1188"] = {"212284","212285","212286"},
    ["1195"] = {"212305","212306","212307"},
    ["1196"] = {"212308","212309","212310"},
    ["1197"] = {"212311","212312","212313"},
    ["1198"] = {"212314","212315","212316"},
    ["1206"] = {"212563","212564","212565"},
    ["1207"] = {"212719","212720","212721"},
    ["1208"] = {"212751","212752","212753"},
    ["1193"] = {"212299","212300","212301"},
    ["1220"] = {"213501","213502","213503"},
    ["1221"] = {"213515","213516","213517"},
    ["1222"] = {"213504","213505","213506"},
    ["1223"] = {"213507","213508","213509"},
    ["1224"] = {"213510","213511","213512"},
    ["1225"] = {"213477","213478","213479"},
    ["1226"] = {"213486","213487","213488"},
    ["1227"] = {"213480","213481","213482"},
    ["1228"] = {"213483","213484","213485"},
    ["1229"] = {"213489","213490","213491"},
    ["1230"] = {"213492","213493","213494"},
    ["1231"] = {"213498","213499","213500"},
    ["1232"] = {"213495","213496","213497"},
    ["1233"] = {"213462","213463","213464"},
    ["1234"] = {"213453","213454","213455"},
    ["1235"] = {"213456","213457","213458"},
    ["1236"] = {"213459","213460","213461"},
    ["1237"] = {"213465","213466","213467"},
    ["1238"] = {"213468","213469","213470"},
    ["1239"] = {"213471","213472","213473"},
    ["1240"] = {"213474","213475","213476"},
    ["1241"] = {"213738","213739","213740"},
    ["1242"] = {"213741","213742","213743"},
    ["1243"] = {"213744","213745","213746"},
    ["1247"] = {"211806","211807","211808"},
    ["1248"] = {"213750","213751","213752"},
    ["1249"] = {"213753","213754","213755"},
    ["1250"] = {"213756","213757","213758"},
    ["1251"] = {"213759","213760","213761"},
    ["1252"] = {"213762","213763","213764"},
    ["1253"] = {"213765","213766","213767"},
    ["1254"] = {"213768","213769","213770"},
    ["1255"] = {"213771","213772","213773"},
    ["1256"] = {"213774","213775","213776"},
    ["1287"] = {"217113","217114","217115"},
    ["1332"] = {"191532","191533","191534"},
    ["1467"] = {"219495","219496","219497"},
    ["1468"] = {"219504","219505","219506"},
    ["1555"] = {"219898","219899","219900"},
    ["1556"] = {"219880","219881","219882"},
    ["1557"] = {"219883","219884","219885"},
    ["1558"] = {"219886","219887","219888"},
    ["1559"] = {"219889","219890","219891"},
    ["1560"] = {"219892","219893","219894"},
    ["1561"] = {"219895","219896","219897"},
    ["1562"] = {"219901","219902","219903"},
    ["1564"] = {"219906","219907","219908"},
    ["1565"] = {"219909","219910","219911"},
    ["1566"] = {"219912","219913","219914"},
    ["1819"] = {"221853","221854","221855"},
    ["1820"] = {"221856","221857","221858"},
    ["1821"] = {"221859","221860","221861"},
    ["1822"] = {"221862","221863","221864"},
    ["1823"] = {"221865","221866","221867"},
    ["1824"] = {"221868","221869","221870"},
    ["1825"] = {"221872","221873","221874"},
    ["1826"] = {"221876","221877","221878"},
    ["1827"] = {"221880","221881","221882"},
    ["1828"] = {"221884","221885","221886"},
    ["1829"] = {"221888","221889","221890"},
    ["1830"] = {"221892","221893","221894"},
    ["1831"] = {"221896","221897","221898"},
    ["1832"] = {"221900","221901","221902"},
    ["1833"] = {"221904","221905","221906"},
    ["1834"] = {"221908","221909","221910"},
    ["1836"] = {"221911","221912","221913"},
    ["1837"] = {"221914","221915","221916"},
    ["1838"] = {"221917","221918","221919"},
    ["1839"] = {"221920","221921","221922"},
    ["1840"] = {"221923","221924","221925"},
    ["1841"] = {"221926","221927","221928"},
    ["1842"] = {"221929","221930","221931"},
    ["1843"] = {"221932","221933","221934"},
    ["1844"] = {"221935","221936","221937"},
    ["1845"] = {"221938","221939","221940"},
    ["1846"] = {"221941","221942","221943"},
    ["1849"] = {"221953","221954","221955"},
    ["2136"] = {"222417","222418","222419"},
    ["2137"] = {"222420","222421","222422"},
    ["2138"] = {"222423","222424","222425"},
    ["2139"] = {"222426","222427","222428"},
    ["2204"] = {"222499","222500","222501"},
    ["2205"] = {"222502","222503","222504"},
    ["2206"] = {"222505","222506","222507"},
    ["2207"] = {"222508","222509","222510"},
    ["2208"] = {"222511","222512","222513"},
    ["2209"] = {"222514","222515","222516"},
    ["2242"] = {"222555","222556","222557"},
    ["2243"] = {"222558","222559","222560"},
    ["2262"] = {"222579","222580","222581"},
    ["2263"] = {"222582","222583","222584"},
    ["2264"] = {"222585","222586","222587"},
    ["2265"] = {"222588","222589","222590"},
    ["2266"] = {"222591","222592","222593"},
    ["2267"] = {"222594","222595","222596"},
    ["2268"] = {"222600","222601","222602"},
    ["2269"] = {"222603","222604","222605"},
    ["2270"] = {"222606","222607","222608"},
    ["2271"] = {"222597","222598","222599"},
    ["2272"] = {"222609","222610","222611"},
    ["2273"] = {"222615","222616","222617"},
    ["2279"] = {"222626","222627","222628"},
    ["2280"] = {"222629","222630","222631"},
    ["2281"] = {"222632","222633","222634"},
    ["2282"] = {"222635","222636","222637"},
    ["2283"] = {"222638","222639","222640"},
    ["2284"] = {"222641","222642","222643"},
    ["2285"] = {"222644","222645","222646"},
    ["2339"] = {"222798","222799","222800"},
    ["2340"] = {"222801","222802","222803"},
    ["2341"] = {"222804","222805","222806"},
    ["2403"] = {"222868","222869","222870"},
    ["2404"] = {"222871","222872","222873"},
    ["2407"] = {"222885","222886","222887"},
    ["2408"] = {"222879","222880","222881"},
    ["2409"] = {"222882","222883","222884"},
    ["2410"] = {"222876","222877","222878"},
    ["2411"] = {"222888","222889","222890"},
    ["2412"] = {"222891","222892","222893"},
    ["2413"] = {"222894","222895","222896"},
    ["2414"] = {"224440","224441","224442"},
    ["1624"] = {"224105","224106","224107"},
    ["1625"] = {"224108","224109","224110"},
    ["1626"] = {"224111","224112","224113"},
    ["1615"] = {"224173","224174","224175"},
    ["1614"] = {"224178","224177","224176"},
    ["1590"] = {"224300","224324","224348"},
    ["1591"] = {"224301","224325","224349"},
    ["1593"] = {"224302","224326","224350"},
    ["1594"] = {"224303","224327","224351"},
    ["1592"] = {"224304","224328","224352"},
    ["1595"] = {"224305","224329","224353"},
    ["1596"] = {"224306","224330","224354"},
    ["1597"] = {"224307","224331","224355"},
    ["1598"] = {"224308","224332","224356"},
    ["1599"] = {"224309","224333","224357"},
    ["1600"] = {"224310","224334","224358"},
    ["1601"] = {"224311","224335","224359"},
    ["1602"] = {"224312","224336","224360"},
    ["1603"] = {"224313","224337","224361"},
    ["1604"] = {"224314","224338","224362"},
    ["1605"] = {"224315","224339","224363"},
    ["1606"] = {"224316","224340","224364"},
    ["1607"] = {"224317","224341","224365"},
    ["1608"] = {"224318","224342","224366"},
    ["1609"] = {"224319","224343","224367"},
    ["1610"] = {"224320","224344","224368"},
    ["1611"] = {"224321","224345","224369"},
    ["1612"] = {"224322","224346","224370"},
    ["1613"] = {"224323","224347","224371"},
    ["2425"] = {"224586","224587","224588"},
    ["2427"] = {"224832","224833","224834"},
    ["2245"] = {"226025","226026","226027"},
    ["2244"] = {"226022","226023","226024"},
    ["2246"] = {"226028","226029","226030"},
    ["2247"] = {"226031","226032","226033"},
    ["2255"] = {"226034","226035","226036"},
    ["2454"] = {"225987","225988","225989"},
    ["1260"] = {"213779","213780","213781"},
    ["1261"] = {"213782","213783","213784"},
    ["1262"] = {"213785","213786","213787"},
    ["1263"] = {"213788","213789","213790"},
    ["1264"] = {"213791","213792","213793"},
    ["2456"] = {"228401","228402","228403"},
    ["2457"] = {"228404","228405","228406"}
}
