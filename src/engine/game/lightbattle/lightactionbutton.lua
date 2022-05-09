local LightActionButton, super = Class(Object)

function LightActionButton:init(type, x, y)
    super:init(self, x, y)

    self.type = type

    self.texture = Assets.getTexture("ui/lightbattle/btn/"..type)
    self.hovered_texture = Assets.getTexture("ui/lightbattle/btn/"..type.."_h")

    self.width = self.texture:getWidth()
    self.height = self.texture:getHeight()

    self:setOriginExact(self.width/2, 13)

    self.hovered = false
    self.selectable = true
end

function LightActionButton:select()
    if self.type == "fight" then
        Game.battle:setState("ENEMYSELECT", "ATTACK")
    elseif self.type == "act" then
        Game.battle:setState("ENEMYSELECT", "ACT")
    elseif self.type == "magic" then
        Game.battle.menu_items = {}

        -- First, register X-Actions as menu items.

        if Game.battle.encounter.default_xactions and self.battler.chara:hasXAct() then
            local item = {
                ["name"] = self.battler.chara:getXActName() or "X-Action",
                ["tp"] = 0,
                ["color"] = {self.battler.chara:getXActColor()},
                ["data"] = {
                    ["name"] = Game.battle.enemies[1]:getXAction(self.battler),
                    ["target"] = "xact",
                    ["id"] = 0,
                    ["default"] = true,
                    ["party"] = {},
                    ["tp"] = 0
                }
            }
            table.insert(Game.battle.menu_items, item)
        end

        for id, action in ipairs(Game.battle.xactions) do
            if action.party == self.battler.chara.id then
                local item = {
                    ["name"] = action.name,
                    ["tp"] = action.tp or 0,
                    ["description"] = action.description,
                    ["color"] = action.color or {1, 1, 1, 1},
                    ["data"] = {
                        ["name"] = action.name,
                        ["target"] = "xact",
                        ["id"] = id,
                        ["default"] = false,
                        ["party"] = {},
                        ["tp"] = action.tp or 0
                    }
                }
                table.insert(Game.battle.menu_items, item)
            end
        end

        -- Now, register SPELLs as menu items.
        for _,spell in ipairs(self.battler.chara:getSpells()) do
            local color = spell.color or {1, 1, 1, 1}
            if spell:hasTag("spare_tired") then
                local has_tired = false
                for _,enemy in ipairs(Game.battle:getActiveEnemies()) do
                    if enemy.tired then
                        has_tired = true
                        break
                    end
                end
                if has_tired then
                    color = {0, 178/255, 1, 1}
                end
            end
            local item = {
                ["name"] = spell:getName(),
                ["tp"] = spell:getTPCost(self.battler.chara),
                ["description"] = spell:getBattleDescription(),
                ["party"] = spell.party,
                ["color"] = color,
                ["data"] = spell
            }
            table.insert(Game.battle.menu_items, item)
        end

        Game.battle:setState("MENUSELECT", "SPELL")
    elseif self.type == "item" then
        Game.battle.menu_items = {}
        for i,item in ipairs(Game.inventory:getStorage("items")) do
            local menu_item = {
                ["name"] = item:getName(),
                ["unusable"] = item.usable_in ~= "all" and item.usable_in ~= "battle",
                ["description"] = item:getBattleDescription(),
                ["data"] = item
            }
            table.insert(Game.battle.menu_items, menu_item)
        end
        if #Game.battle.menu_items > 0 then
            Game.battle:setState("MENUSELECT", "ITEM")
        end
    elseif self.type == "spare" then
        Game.battle:setState("ENEMYSELECT", "SPARE")
    elseif self.type == "defend" then
        Game.battle:pushAction("DEFEND", nil, {tp = -16})
    end
end

function LightActionButton:unselect()
    -- Do nothing ?
end

function LightActionButton:draw()
    if self.selectable and self.hovered then
        love.graphics.draw(self.hovered_texture or self.texture)
    else
        love.graphics.draw(self.texture)
    end

    super:draw(self)
end

return LightActionButton