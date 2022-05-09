local LightBattle, super = Class(Battle)

function LightBattle:init()
    super:init(self)

    -- states: BATTLETEXT, TRANSITION, ACTIONSELECT, ENEMYSELECT, ACTSELECT, ITEMSELECT, MERCYSELECT, ENEMYDIALOGUE, DEFENDING, VICTORY, TRANSITIONOUT, ATTACKING, FLEEING
    self.post_battletext_state = "ACTIONSELECT"

    for i, v in ipairs(self.party) do
        if Game.world.player and Game.world.player.actor.id == v.chara.id then
            -- TODO: find a better way to do this...?
            local sprite = Game.world.player.sprite:getDirectionalPath(Game.world.player.sprite.sprite)
            v:setSprite(sprite)
        else
            v:remove()
        end
    end
    self.party = {self.party[1]}

    self.fader = Fader()
    self.fader.layer = 1000
    self.fader.alpha = 1
    self:addChild(self.fader)

    self.party[1].layer = self.fader.layer + 1


    self.buttons = {
        self:addChild(LightActionButton("fight", 87, 445)),
        self:addChild(LightActionButton("act",   240, 445)),
        self:addChild(LightActionButton("item",  400, 445)),
        self:addChild(LightActionButton("mercy", 555, 445))
    }

    self.buttons[1].hovered = true

    self.selected_button = 1
end

function LightBattle:postInit(state, encounter)
    self.state = state

    if type(encounter) == "string" then
        self.encounter = Registry.createEncounter(encounter)
    else
        self.encounter = encounter
    end

    if Game.world.music:isPlaying() then
        self.resume_world_music = true
        Game.world.music:pause()
    end

    self.battler_targets = {}
    if state == "TRANSITION" then
        self.transitioned = true
        self.transition_timer = 0
        for _,enemy in ipairs(self.enemies) do
            self.enemy_beginning_positions[enemy] = {enemy.x, enemy.y}
        end

        Game.battle.timer:script(function(wait)
            -- Black bg
            wait(1/30)
            -- Show heart
            Assets.playSound("noise")
            self:spawnSoul(x, y)
            self.soul.sprite:set("player/heart_menu")
            self.soul.layer = self.fader.layer + 2
            self.soul:setScale(2)
            self.soul.can_move = false
            wait(2/30)
            -- Hide heart
            self.soul.visible = false
            wait(2/30)
            -- Show heart
            self.soul.visible = true
            Assets.playSound("noise")
            wait(2/30)
            -- Hide heart
            self.soul.visible = false
            wait(2/30)
            -- Show heart
            self.soul.visible = true
            Assets.playSound("noise")
            wait(2/30)
            -- Do transition
            self.party[1].visible = false
            Assets.playSound("battlefall")
            self.soul:slideTo(49, 455, 17/30) -- TODO: maybe just give soul:transition a speed argument...?
            wait(17/30)
            -- Wait
            wait(5/30)
            self.soul:setScale(1)
            self.soul.sprite:set("player/heart")
            self.soul.x = self.soul.x - 1
            self.soul.y = self.soul.y - 1
            self:setState("ACTIONSELECT")
            self.fader:fadeIn(nil, {speed=5/30})
        end)
    else
        --self.transition_timer = 10
    end

    self.arena = LightArena(SCREEN_WIDTH/2, 385)
    self.arena.layer = BATTLE_LAYERS["arena"]
    self:addChild(self.arena)

    self.encounter_text = Textbox(14, 17, SCREEN_WIDTH - 30, SCREEN_HEIGHT - 53, "main_mono", nil, true)
    self.encounter_text.text.line_offset = 0
    self.encounter_text.text.style = "none"
    self.encounter_text.text.state.typing_sound = "ut"
    self.encounter_text:setText("")
    self.encounter_text.text.state.typing_sound = "ut"
    self.encounter_text.debug_select = false
    self.arena:addChild(self.encounter_text)

    self:setState(state)
end

function LightBattle:spawnSoul(x, y)
    local bx, by = self:getSoulLocation()
    x = x or bx
    y = y or by

    local color = {Game:getSoulColor()}
    if not self.soul then
        self.soul = self.encounter:createSoul(bx, by, color)
        self.soul.alpha = 1
        self:addChild(self.soul)
    end
end

function LightBattle:getSoulLocation(always_player)
    if self.soul and (not always_player) then
        return self.soul:getPosition()
    else
        local main_chara = Game:getSoulPartyMember()

        if main_chara and main_chara:getSoulPriority() >= 0 then
            local battler = self.party[self:getPartyIndex(main_chara.id)]

            if battler then
                return battler:localToScreenPos((battler.sprite.width/2), battler.sprite.height/2 + 5)
            end
        end
        return -9, -9
    end
end

function LightBattle:setState(state, reason)
    local old = self.state
    self.state = state
    self.state_reason = reason
    self:onStateChange(old, self.state)
end

function LightBattle:setSubState(state, reason)
    local old = self.substate
    self.substate = state
    self.substate_reason = reason
    self:onSubStateChange(old, self.substate)
end

function LightBattle:getState()
    return self.state
end

function LightBattle:onStateChange(old,new)
    if self.encounter.beforeStateChange then
        local result = self.encounter:beforeStateChange(old,new)
        if result or self.state ~= new then
            return
        end
    end

    if new == "ACTIONSELECT" then
        if self.state_reason == "CANCEL" then
            --self.battle_ui.encounter_text:setText("[instant]" .. self.battle_ui.current_encounter_text)
        end
        self.encounter_text:setText(self.encounter.text)
        self.encounter_text.text.state.typing_sound = "ut"
        local had_started = self.started
        if not self.started then
            self.started = true

            --if self.encounter.music then
            --    self.music:play(self.encounter.music)
            --end
            self.music:play("battleut")
        end
    elseif new == "ENEMYSELECT"then
        --self.battle_ui.encounter_text:setText("")
        self.current_menu_y = 1
        self.selected_enemy = 1
    elseif new == "MENUSELECT" then
        --self.battle_ui.encounter_text:setText("")
        self.current_menu_x = 1
        self.current_menu_y = 1
    elseif new == "ATTACKING" then
        --self.battle_ui.encounter_text:setText("")
    elseif new == "ENEMYDIALOGUE" then
        --self.battle_ui.encounter_text:setText("")
        self.textbox_timer = 3 * 30
        self.use_textbox_timer = true
        local active_enemies = self:getActiveEnemies()
        if #active_enemies == 0 then
            self:setState("VICTORY")
        else
            local cutscene_args = {self.encounter:getDialogueCutscene()}
            if #cutscene_args > 0 then
                self:startCutscene(unpack(cutscene_args)):after(function()
                    self:setState("DEFENDING", "ENEMYDIALOGUE")
                end)
            else
                local any_dialogue = false
                for _,enemy in ipairs(active_enemies) do
                    local dialogue = enemy:getEnemyDialogue()
                    if dialogue then
                        any_dialogue = true
                        local textbox = self:spawnEnemyTextbox(enemy, dialogue)
                        table.insert(self.enemy_dialogue, textbox)
                    end
                end
                if not any_dialogue then
                    self:setState("DEFENDING", "ENEMYDIALOGUE")
                end
            end
        end
    elseif new == "DIALOGUEEND" then
        if self.state_reason == "ENEMYDIALOGUE" then
            self.encounter:onDialogueEnd()
        end
        --self.battle_ui.encounter_text:setText("")
    elseif new == "DEFENDING" then
        self.wave_length = 0
        self.wave_timer = 0

        for _,wave in ipairs(self.waves) do
            wave.encounter = self.encounter

            self.wave_length = math.max(self.wave_length, wave.time)

            wave:onStart()

            wave.active = true
        end
    elseif new == "VICTORY" then
        self.music:stop()

        self.money = math.floor(self.money)

        Game.money = Game.money + self.money
        Game.xp = Game.xp + self.xp

        if (Game.money < 0) then
            Game.money = 0
        end

        local win_text = "* YOU WON!\n* You earned " .. self.xp .. " EXP and " .. self.money .. " gold."

        if self.encounter.no_end_message then
            self:setState("TRANSITIONOUT")
            self.encounter:onBattleEnd()
        else
            self:battleText(win_text, function()
                self:setState("TRANSITIONOUT")
                self.encounter:onBattleEnd()
                return true
            end)
        end
    elseif new == "TRANSITIONOUT" then
    end

    if self.encounter.onStateChange then
        self.encounter:onStateChange(old,new)
    end
end

function LightBattle:getEnemyBattler(string_id)
    for _, enemy in ipairs(self.enemies) do
        if enemy.id == string_id then
            return enemy
        end
    end
end

function LightBattle:hurt(amount, exact)
    if self.player then
        player:hurt(amount, exact)
    end
end

function LightBattle:checkGameOver()
    if self.player.health <= 0 then
        self.music:stop()
        Game:gameOver(self:getSoulLocation())
    end
end

function LightBattle:battleText(text,post_func)
    local target_state = self:getState()

    self.encounter_text:setText(text, function()
        self.encounter_text:setText("")
        if type(post_func) == "string" then
            target_state = post_func
        elseif type(post_func) == "function" and post_func() then
            return
        end
        self:setState(target_state)
    end)
    self.encounter_text:setAdvance(true)

    self:setState("BATTLETEXT")
end

function LightBattle:update()
    for _,enemy in ipairs(self.enemies_to_remove) do
        Utils.removeFromTable(self.enemies, enemy)
    end
    self.enemies_to_remove = {}

    if self.cutscene then
        if not self.cutscene.ended then
            self.cutscene:update()
        else
            self.cutscene = nil
        end
    end

    if self.state == "TRANSITION" then
        self:updateTransition()
    elseif self.state == "ATTACKING" then
        self:updateAttacking()
    elseif self.state == "DEFENDING" then
        self:updateWaves()
    elseif self.state == "ENEMYDIALOGUE" then
        self.textbox_timer = self.textbox_timer - DTMULT
        if (self.textbox_timer <= 0) and self.use_textbox_timer then
            self:advanceBoxes()
        else
            local all_done = true
            for _,textbox in ipairs(self.enemy_dialogue) do
                if not textbox:isDone() then
                    all_done = false
                    break
                end
            end
            if all_done then
                self:setState("DIALOGUEEND")
            end
        end
    elseif self.state == "ACTIONSELECT" then
        self:snapSoulToButton()
    end

    if self.state ~= "TRANSITIONOUT" then
        self.encounter:update()
    end

    if self.shake ~= 0 then
        local last_shake = math.ceil(self.shake)
        self.camera.ox = last_shake
        self.camera.oy = last_shake
        self.shake = Utils.approach(self.shake, 0, DTMULT)
        local new_shake = math.ceil(self.shake)
        if new_shake ~= last_shake then
            self.shake = self.shake * -1
        end
    else
        self.camera.ox = 0
        self.camera.oy = 0
    end

    -- Always sort
    --self.update_child_list = true
    super:update(self)

    if self.state == "TRANSITIONOUT" then
        self:updateTransitionOut()
    end
end

function LightBattle:updateTransition()
    self.transition_timer = self.transition_timer + DTMULT

    --[[ frame 1 - black bg
         frame 2 - heart
         frame 3 - heart
         frame 4 - no heart
         frame 5 - no heart
         frame 6 - heart
         frame 7 - heart
         frame 8 - no heart
         frame 9 - no heart
         frame 10 - heart
         frame 11 - heart
         frame 12 - no frisk, start moving
         frame 30 - stop moving
         frame 35 - fade in, transition heart fades out
    ]]

    --if self.transition_timer >= 35 then
    --    self.transition_timer = 35
    --    self:setState("ACTIONSELECT")
    --end
end

function LightBattle:updateTransitionOut()
    self.transition_timer = self.transition_timer - DTMULT

    if self.transition_timer <= 0 then
        self:returnToWorld()
        return
    end
end

function LightBattle:draw()
    if self.encounter.background then
        self:drawBackground()
    end

    self.encounter:drawBackground(0)

    love.graphics.setFont(Assets.getFont("namelv", 24))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("KRIS  LV 1", 30, 400)

    love.graphics.draw(Assets.getTexture("ui/lightbattle/hpname"), 244, 405)

    local max = Game.party[1]:getStat("health")
    local current = Game.party[1].health
    local size = max * 1.25
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("fill", 275, 400, size, 21)
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.rectangle("fill", 275, 400, current * 1.25, 21)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(current .. " / " .. max, 275 + size + 14, 400)

    super.super:draw(self)

    self.encounter:draw()

    if DEBUG_RENDER then
        self:drawDebug()
    end
end

function LightBattle:drawBackground()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", -8, -8, SCREEN_WIDTH+16, SCREEN_HEIGHT+16)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Assets.getTexture("ui/lightbattle/background"), 15, 9)
end

function LightBattle:advanceBoxes()
    local all_done = true
    local to_remove = {}
    -- Check if any dialogue is typing
    for _,dialogue in ipairs(self.enemy_dialogue) do
        if dialogue:isTyping() then
            all_done = false
            break
        end
    end
    -- Nothing is typing, try to advance
    if all_done then
        self.textbox_timer = 3 * 30
        self.use_textbox_timer = true
        for _,dialogue in ipairs(self.enemy_dialogue) do
            dialogue:advance()
            if not dialogue:isDone() then
                all_done = false
            else
                table.insert(to_remove, dialogue)
            end
        end
    end
    -- Remove leftover dialogue
    for _,dialogue in ipairs(to_remove) do
        Utils.removeFromTable(self.enemy_dialogue, dialogue)
    end
    -- If all dialogue is done, go to DEFENDING state
    if all_done then
        self:setState("DEFENDING")
    end
end

function LightBattle:keypressed(key)
    if OVERLAY_OPEN then return end

    if Kristal.Config["debug"] and (Input.keyDown("lctrl") or Input.keyDown("rctrl")) then
        if key == "h" then
            for _,party in ipairs(self.party) do
                party:heal(math.huge)
            end
        end
        if key == "y" then
            Input.clear()
            self:setState("VICTORY")
        end
        if key == "m" then
            if self.music then
                if self.music:isPlaying() then
                    self.music:pause()
                else
                    self.music:resume()
                end
            end
        end
        if self.state == "DEFENDING" and key == "f" then
            self.encounter:onWavesDone()
        end
    end

    if self.state == "MENUSELECT" then
        local menu_width = 2
        local menu_height = math.ceil(#self.menu_items / 2)

        if Input.isConfirm(key) then
            if self.state_reason == "ACT" then
                local menu_item = self.menu_items[self:getItemIndex()]
                if self:canSelectMenuItem(menu_item) then
                    self.ui_select:stop()
                    self.ui_select:play()

                    self:pushAction("ACT", self.enemies[self.selected_enemy], menu_item)
                end
                return
            elseif self.state_reason == "SPELL" then
                local menu_item = self.menu_items[self:getItemIndex()]
                self.selected_spell = menu_item
                if self:canSelectMenuItem(menu_item) then
                    self.ui_select:stop()
                    self.ui_select:play()

                    if menu_item.data.target == "xact" then
                        self.selected_xaction = menu_item.data
                        self:setState("XACTENEMYSELECT", "SPELL")
                    elseif not menu_item.data.target or menu_item.data.target == "none" then
                        self:pushAction("SPELL", nil, menu_item)
                    elseif menu_item.data.target == "ally" then
                        self:setState("PARTYSELECT", "SPELL")
                    elseif menu_item.data.target == "enemy" then
                        self:setState("ENEMYSELECT", "SPELL")
                    elseif menu_item.data.target == "party" then
                        self:pushAction("SPELL", self.party, menu_item)
                    elseif menu_item.data.target == "enemies" then
                        self:pushAction("SPELL", self:getActiveEnemies(), menu_item)
                    end
                end
                return
            elseif self.state_reason == "ITEM" then
                local menu_item = self.menu_items[self:getItemIndex()]
                self.selected_item = menu_item
                if self:canSelectMenuItem(menu_item) then
                    self.ui_select:stop()
                    self.ui_select:play()
                    if not menu_item.data.target or menu_item.data.target == "none" then
                        self:pushAction("ITEM", nil, menu_item)
                    elseif menu_item.data.target == "ally" then
                        self:setState("PARTYSELECT", "ITEM")
                    elseif menu_item.data.target == "enemy" then
                        self:setState("ENEMYSELECT", "ITEM")
                    elseif menu_item.data.target == "party" then
                        self:pushAction("ITEM", self.party, menu_item)
                    elseif menu_item.data.target == "enemies" then
                        self:pushAction("ITEM", self:getActiveEnemies(), menu_item)
                    end
                end
            end
        elseif Input.isCancel(key) then
            self.ui_move:stop()
            self.ui_move:play()
            self.tension_bar:setTensionPreview(0)
            self:setState("ACTIONSELECT", "CANCEL")
            return
        elseif Input.is("left", key) then -- TODO: pagination
            self.current_menu_x = self.current_menu_x - 1
            if self.current_menu_x < 1 then
                self.current_menu_x = menu_width
                if not self:isValidMenuLocation() then
                    self.current_menu_x = 1
                end
            end
        elseif Input.is("right", key) then
            self.current_menu_x = self.current_menu_x + 1
            if not self:isValidMenuLocation() then
                self.current_menu_x = 1
            end
        end
        if Input.is("up", key) then
            self.current_menu_y = self.current_menu_y - 1
            if self.current_menu_y < 1 then
                self.current_menu_y = 1 -- No wrapping in this menu.
            end
        elseif Input.is("down", key) then
            self.current_menu_y = self.current_menu_y + 1
            if (self.current_menu_y > menu_height) or (not self:isValidMenuLocation()) then
                self.current_menu_y = menu_height -- No wrapping in this menu.
                if not self:isValidMenuLocation() then
                    self.current_menu_y = menu_height - 1
                end
            end
        end
    elseif self.state == "ENEMYSELECT" or self.state == "XACTENEMYSELECT" then
        if Input.isConfirm(key) then
            self.ui_select:stop()
            self.ui_select:play()
            self.selected_enemy = self.current_menu_y
            if self.state == "XACTENEMYSELECT" then
                self:pushAction("XACT", self.enemies[self.selected_enemy], self.selected_xaction)
            elseif self.state_reason == "SPARE" then
                self:pushAction("SPARE", self.enemies[self.selected_enemy])
            elseif self.state_reason == "ACT" then
                self.menu_items = {}
                local enemy = self.enemies[self.selected_enemy]
                for _,v in ipairs(enemy.acts) do
                    local insert = true
                    if v.character and self.party[self.current_selecting].chara.id ~= v.character then
                        insert = false
                    end
                    if v.party and (#v.party > 0) then
                        for _,party_id in ipairs(v.party) do
                            if not self:getPartyIndex(party_id) then
                                insert = false
                                break
                            end
                        end
                    end
                    if insert then
                        local item = {
                            ["name"] = v.name,
                            ["tp"] = v.tp or 0,
                            ["description"] = v.description,
                            ["party"] = v.party,
                            ["color"] = {1, 1, 1, 1},
                            ["highlight"] = v.highlight or enemy
                        }
                        table.insert(self.menu_items, item)
                    end
                end
                self:setState("MENUSELECT", "ACT")
            elseif self.state_reason == "ATTACK" then
                self:pushAction("ATTACK", self.enemies[self.selected_enemy])
            elseif self.state_reason == "SPELL" then
                self:pushAction("SPELL", self.enemies[self.selected_enemy], self.selected_spell)
            elseif self.state_reason == "ITEM" then
                self:pushAction("ITEM", self.enemies[self.selected_enemy], self.selected_item)
            else
                self:nextParty()
            end
            return
        end
        if Input.isCancel(key) then
            self.ui_move:stop()
            self.ui_move:play()
            if self.state_reason == "SPELL" then
                self:setState("MENUSELECT", "SPELL")
            elseif self.state_reason == "ITEM" then
                self:setState("MENUSELECT", "ITEM")
            else
                self:setState("ACTIONSELECT", "CANCEL")
            end
            return
        end
        if Input.is("up", key) then
            self.ui_move:stop()
            self.ui_move:play()
            self.current_menu_y = self.current_menu_y - 1
            if self.current_menu_y < 1 then
                self.current_menu_y = #self.enemies
            end
        elseif Input.is("down", key) then
            self.ui_move:stop()
            self.ui_move:play()
            self.current_menu_y = self.current_menu_y + 1
            if self.current_menu_y > #self.enemies then
                self.current_menu_y = 1
            end
        end
    elseif self.state == "PARTYSELECT" then
        if Input.isConfirm(key) then
            self.ui_select:stop()
            self.ui_select:play()
            if self.state_reason == "SPELL" then
                self:pushAction("SPELL", self.party[self.current_menu_y], self.selected_spell)
            elseif self.state_reason == "ITEM" then
                self:pushAction("ITEM", self.party[self.current_menu_y], self.selected_item)
            else
                self:nextParty()
            end
            return
        end
        if Input.isCancel(key) then
            self.ui_move:stop()
            self.ui_move:play()
            if self.state_reason == "SPELL" then
                self:setState("MENUSELECT", "SPELL")
            elseif self.state_reason == "ITEM" then
                self:setState("MENUSELECT", "ITEM")
            else
                self:setState("ACTIONSELECT", "CANCEL")
            end
            return
        end
        if Input.is("up", key) then
            self.ui_move:stop()
            self.ui_move:play()
            self.current_menu_y = self.current_menu_y - 1
            if self.current_menu_y < 1 then
                self.current_menu_y = #self.party
            end
        elseif Input.is("down", key) then
            self.ui_move:stop()
            self.ui_move:play()
            self.current_menu_y = self.current_menu_y + 1
            if self.current_menu_y > #self.party then
                self.current_menu_y = 1
            end
        end
    elseif self.state == "BATTLETEXT" then
        -- Nothing here
    elseif self.state == "ENEMYDIALOGUE" then
        -- Nothing here
    elseif self.state == "ACTIONSELECT" then

        if Input.isConfirm(key) then
            self.ui_select:stop()
            self.ui_select:play()
            return
        elseif Input.isCancel(key) then
            local old_selecting = self.current_selecting

            self:previousParty()

            if self.current_selecting ~= old_selecting then
                self.ui_move:stop()
                self.ui_move:play()
            end
            return
        elseif Input.is("left", key) then
            self.ui_move:stop()
            self.ui_move:play()
            self.selected_button = self.selected_button - 1
            if self.selected_button < 1 then self.selected_button = #self.buttons end
            for i, v in ipairs(self.buttons) do
                v.hovered = false
            end
            self.buttons[self.selected_button].hovered = true
            self:snapSoulToButton()
        elseif Input.is("right", key) then
            self.ui_move:stop()
            self.ui_move:play()
            self.selected_button = self.selected_button + 1
            if self.selected_button > #self.buttons then self.selected_button = 1 end
            for i, v in ipairs(self.buttons) do
                v.hovered = false
            end
            self.buttons[self.selected_button].hovered = true
            self:snapSoulToButton()
        end
    elseif self.state == "ATTACKING" then
    end
end

function LightBattle:snapSoulToButton()
    self.soul.x = self.buttons[self.selected_button].x - 39
    self.soul.y = self.buttons[self.selected_button].y + 9
end

return LightBattle