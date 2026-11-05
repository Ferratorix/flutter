extends BaseScreen
## Финансовые цели: список, общий прогресс, создание.


func _ready() -> void:
	build_scroll_layout()
	_build()
	DataManager.goals_changed.connect(_build)
	DataManager.profile_changed.connect(_build)


func _build() -> void:
	UI.clear_children(content)
	content.add_child(UI.top_bar("Финансовые цели"))
	var profile := DataManager.profile
	if not profile.is_valid():
		add_profile_required_card(content)
		return
	var goals := DataManager.goals
	if goals.is_empty():
		UI.empty_state(content, "target", "Целей пока нет",
			"Поставьте цель — например, отпуск или подушку безопасности. TIMEPRICE покажет прогресс, срок при регулярном взносе и сколько рабочего времени осталось.")
		content.add_child(UI.button("Создать цель", &"PrimaryButton", _create))
		return
	_build_summary(goals, profile)
	for goal in goals:
		var box := UI.tap_card(content, _open.bind(goal.id))
		GoalView.fill_summary(box, goal, profile)
		UI.pass_through(box)
	if DataManager.can_add_goal():
		content.add_child(UI.button("Новая цель", &"SecondaryButton", _create))


func _build_summary(goals: Array[FinancialGoal], profile: UserProfile) -> void:
	var saved := 0
	var target := 0
	var completed := 0
	for g in goals:
		if g.currency != profile.currency:
			continue
		saved = mini(saved + g.saved_minor, Money.MAX_MINOR)
		target = mini(target + g.target_minor, Money.MAX_MINOR)
		if g.is_completed():
			completed += 1
	if target <= 0:
		return
	var box := UI.card(content, &"AccentCard", 6)
	box.add_child(UI.label("Накоплено по всем целям", &"CaptionLabel"))
	box.add_child(UI.label(Fmt.money(saved, profile.currency), &"DisplayLabel", true))
	box.add_child(UI.label(Loc.tf("из %s · достигнуто целей: %d из %d", [Fmt.money(target, profile.currency), completed, goals.size()]), &"CaptionLabel", true))
	box.add_child(UI.progress_bar(FinancialCalculator.goal_progress(saved, target)))


func _create() -> void:
	NavigationManager.push("goal_edit")


func _open(id: String) -> void:
	NavigationManager.push("goal_detail", {"id": id})
