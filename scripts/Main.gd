extends Control

var peer = ENetMultiplayerPeer.new()
const PORT = 7000

var value := 50.0 
var timer := 60
var correct_answer := 0 
var is_game_over := false
var player_team := 0 
var game_mode := "ADIÇÃO" 

# Referências principais
@onready var menu_inicial = $MenuInicial
@onready var arena_de_jogo = $ArenaDeJogo

# Nós que agora estão DENTRO da ArenaDeJogo
@onready var bar_bg = $ArenaDeJogo/BarBG
@onready var marcador = $ArenaDeJogo/BarBG/Marcador
@onready var question_label = $ArenaDeJogo/QuestionLabel
@onready var timer_label = $ArenaDeJogo/TimerLabel
@onready var keypad_container = $ArenaDeJogo/KeypadContainer
@onready var label_time_azul = $ArenaDeJogo/BarBG/LabelTimeAzul
@onready var label_time_vermelho = $ArenaDeJogo/BarBG/LabelTimeVermelho

# Inputs técnicos (também dentro da Arena)
@onready var team1_input = $ArenaDeJogo/Team1Input
@onready var team2_input = $ArenaDeJogo/Team2Input

# Sons e Botões do Menu (continuam fora ou em caminhos específicos)
@onready var musica_fundo = $MusicaFundo
@onready var som_vitoria = $SomVitoria
@onready var host_button = $MenuInicial/VBoxContainer/HostButton
@onready var join_button = $MenuInicial/VBoxContainer/JoinButton

func _ready():
	arena_de_jogo.visible = false
	menu_inicial.visible = true
	# 1. Configuração inicial
	set_ui_visibility(false)
	menu_inicial.show()

	
	# 2. Conecta os Sinais do Menu
	menu_inicial.host_requested.connect(_on_host_pressed)
	menu_inicial.join_requested.connect(_on_join_pressed)
	
	# 3. Conecta Modos de Jogo (Caminho novo com GridContainer)
	var path_grid = "MenuInicial/VBoxContainer/GridContainer/"
	if has_node(path_grid + "BtnAdicao"):
		get_node(path_grid + "BtnAdicao").pressed.connect(func(): set_game_mode("ADIÇÃO"))
	if has_node(path_grid + "BtnSubtracao"):
		get_node(path_grid + "BtnSubtracao").pressed.connect(func(): set_game_mode("SUBTRAÇÃO"))
	if has_node(path_grid + "BtnMulti"):
		get_node(path_grid + "BtnMulti").pressed.connect(func(): set_game_mode("MULTIPLICAÇÃO"))
	if has_node(path_grid + "BtnDivisao"):
		get_node(path_grid + "BtnDivisao").pressed.connect(func(): set_game_mode("DIVISÃO"))

	create_keypad()
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	# 5. AJUSTES VISUAIS DOS CAMPOS DE TEXTO
	# Mude de $Team1Input para o caminho completo ou use a variável @onready
	$ArenaDeJogo/Team1Input.add_theme_font_size_override("font_size", 50)
	$ArenaDeJogo/Team2Input.add_theme_font_size_override("font_size", 50)
	$ArenaDeJogo/Team1Input.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	$ArenaDeJogo/Team2Input.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER

# --- LÓGICA DO TECLADO VIRTUAL (KEYPAD) ---

func create_keypad():
	print("Tentando criar o teclado...")
	if not keypad_container: 
		print("ERRO: KeypadContainer não encontrado!")
		return
	
	# Garante que o container esteja no lugar certo
	keypad_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	keypad_container.columns = 3
	
	# Limpa botões existentes
	for child in keypad_container.get_children():
		child.queue_free()
		
	# ORDEM ATUALIZADA: 7,8,9 | 4,5,6 | 1,2,3 | C, 0, OK (0 no meio)
	var ordem_teclas = ["7", "8", "9", "4", "5", "6", "1", "2", "3", "C", "0", "OK"]
	
	for txt in ordem_teclas:
		make_button(txt)

func make_button(txt):
	var btn = Button.new()
	btn.text = txt
	
	# TAMANHO AMPLIADO PARA O APK:
	# Como você quer maior que 120x120, usamos 180x180 para ocupar bem a tela
	btn.custom_minimum_size = Vector2(180, 180) 
	
	# Fonte aumentada para 55 conforme solicitado para clareza no celular
	btn.add_theme_font_size_override("font_size", 55)
	
	# Configurações de comportamento
	if txt == "C":
		btn.pressed.connect(_on_clear_pressed)
		btn.modulate = Color(1, 0.3, 0.3) # Vermelho
	elif txt == "OK":
		btn.pressed.connect(_on_submit_keypad)
		btn.modulate = Color(0.3, 1, 0.3) # Verde
	else:
		btn.pressed.connect(func(): _on_number_pressed(txt))
		
	keypad_container.add_child(btn)

func _on_number_pressed(valor: String):
	# Usamos as variáveis que já têm o endereço certo
	if player_team == 1: 
		team1_input.text += valor
	else: 
		team2_input.text += valor

func _on_clear_pressed():
	# Usamos as variáveis que já criamos para evitar erros de caminho
	if player_team == 1: 
		team1_input.text = ""
	else: 
		team2_input.text = ""



func _on_submit_keypad():
	if player_team == 1: _on_team1_answer()
	else: _on_team2_answer()

# --- LÓGICA DO JOGO E REDE ---

func set_game_mode(mode):
	game_mode = mode
	print("Modo selecionado: ", game_mode)

func update_bar():
	if not bar_bg or not marcador: return
	
	# Pega a largura da imagem da corda (TextureRect)
	var largura_total = bar_bg.size.x
	
	# Calcula a posição baseada no 'value' (0 a 100)
	# 0 = Extrema esquerda | 100 = Extrema direita
	var destino_x = (value / 100.0) * largura_total
	
	var tween = create_tween()
	
	# Como o Sprite2D está centralizado, movemos o 'position.x' dele
	# O 0.5 é o tempo da animação para ficar suave
	tween.tween_property(marcador, "position:x", destino_x, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

@rpc("any_peer", "call_local")
func check_answer_server(answer, team):
	if !multiplayer.is_server() or is_game_over: return
	var deslocamento = 10.0
	var acertou = (answer == correct_answer)
	
	if team == 1:
		if acertou: value -= deslocamento 
		else: value += deslocamento
	elif team == 2:
		if acertou: value += deslocamento 
		else: value -= deslocamento 

	value = clamp(value, 0.0, 100.0)
	sync_game_state.rpc(value)

	if value <= 0: show_game_over.rpc("AZUL VENCEU!")
	elif value >= 100: show_game_over.rpc("VERMELHO VENCEU!")
	elif !is_game_over: generate_new_question()

@rpc("authority", "call_local")
func sync_question_ui(a, b, op_symbol, result):
	correct_answer = result
	question_label.text = "%d %s %d = ?" % [a, op_symbol, b]

func generate_new_question():
	if !multiplayer.is_server(): return
	var a = randi() % 10 + 1
	var b = randi() % 10 + 1
	var symbol = "+"
	var result = 0
	
	match game_mode:
		"ADIÇÃO":
			symbol = "+"
			result = a + b
		"SUBTRAÇÃO":
			symbol = "-"
			if a < b:
				var temp = a
				a = b
				b = temp
			result = a - b
		"MULTIPLICAÇÃO":
			symbol = "x"
			result = a * b
		"DIVISÃO":
			symbol = "÷"
			result = randi() % 10 + 1
			a = result * b 
			
	sync_question_ui.rpc(a, b, symbol, result)

@rpc("authority", "call_local")
func sync_game_state(new_value):
	value = new_value
	update_bar()

@rpc("authority", "call_local")
func sync_timer(new_timer):
	timer = new_timer
	timer_label.text = "Tempo: %d" % timer

@rpc("authority", "call_local")
func sync_game_mode(mode):
	game_mode = mode

func start_timer():
	if !multiplayer.is_server(): return
	var t = get_tree().create_timer(1.0)
	t.timeout.connect(func():
		if !is_game_over:
			timer -= 1
			sync_timer.rpc(timer)
			if timer <= 0:
				var winner = "AZUL VENCEU!" if value < 50 else "VERMELHO VENCEU!"
				show_game_over.rpc("TEMPO ESGOTADO!\n" + winner)
			else: start_timer()
	)

func _on_host_pressed():
	print("Main recebeu o pedido de Host! Iniciando servidor...") # <--- Adicione este print
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	player_team = 1
	menu_inicial.visible = false
	arena_de_jogo.visible = true
	question_label.visible = true
	
	var meu_ip = ""
	for adr in IP.get_local_addresses():
		if adr.begins_with("192.168.") or adr.begins_with("10."):
			meu_ip = adr
			break
	question_label.text = "AGUARDANDO OPONENTE...\nIP: " + meu_ip

func _on_join_pressed(ip_digitado = ""):
	menu_inicial.visible = false
	arena_de_jogo.visible = true
	var ip = ip_digitado
	# Se o sinal vier vazio, tenta pegar direto do nó
	if ip == "":
		ip = $MenuInicial/VBoxContainer/IPInput.text
	
	if ip == "": ip = "127.0.0.1"
	
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer
	player_team = 2
	menu_inicial.visible = false
	arena_de_jogo.visible = true
	question_label.visible = true
	question_label.text = "CONECTANDO AO IP: " + ip
	


func _on_peer_connected(_id):
	if multiplayer.is_server():
		sync_game_mode.rpc(game_mode)
		start_game.rpc()

@rpc("authority", "call_local")
func start_game():
	set_ui_visibility(true)
	update_bar()
	
	# Identifica o time do jogador local
	if player_team == 1:
		# Eu sou o Host (Lado Esquerdo / Azul)
		label_time_azul.text = "MEU TIME (AZUL)"
		label_time_vermelho.text = "OPONENTE (VERMELHO)"
	else:
		# Eu sou o Cliente (Lado Direito / Vermelho)
		label_time_azul.text = "OPONENTE (AZUL)"
		label_time_vermelho.text = "MEU TIME (VERMELHO)"
		
	if musica_fundo:
		musica_fundo.volume_db = 0 # Garante que o volume esteja normal ao começar
		musica_fundo.play()
		
	if multiplayer.is_server():
		question_label.text = "PREPARAR..." 
		await get_tree().create_timer(1.5).timeout
		generate_new_question()
		start_timer()

func _on_team1_answer():
	# Usamos a variável 'team1_input' que já tem o caminho correto
	if team1_input.text != "" and player_team == 1:
		check_answer_server.rpc_id(1, int(team1_input.text), 1)
		team1_input.text = ""

func _on_team2_answer():
	# Usamos a variável 'team2_input' que já tem o caminho correto
	if team2_input.text != "" and player_team == 2:
		check_answer_server.rpc_id(1, int(team2_input.text), 2)
		team2_input.text = ""

func set_ui_visibility(p_visible: bool):
	# Se p_visible for true: mostra o jogo e esconde o menu
	# Se p_visible for false: esconde o jogo e mostra o menu (limpo!)
	arena_de_jogo.visible = p_visible
	menu_inicial.visible = !p_visible
	
	# Os inputs continuam precisando da lógica de time
	$ArenaDeJogo/Team1Input.visible = p_visible and player_team == 1
	$ArenaDeJogo/Team2Input.visible = p_visible and player_team == 2
	# Caso ele ainda teime em sumir, force aqui:
	if keypad_container:
		keypad_container.visible = p_visible
	if !p_visible:
		question_label.text = ""
		timer_label.text = "Tempo: 60"
		team1_input.text = ""
		team2_input.text = ""
	
	# Se você tem labels escritas "Meu Time", esconda-as aqui também:
	#if has_node("LabelTimeAzul"): $LabelTimeAzul.visible = p_visible
	#if has_node("LabelTimeVermelho"): $LabelTimeVermelho.visible = p_visible

@rpc("authority", "call_local")
func show_game_over(txt):
	is_game_over = true
	
	# --- AJUSTE: FADE OUT DA MÚSICA ---
	if musica_fundo and musica_fundo.playing:
		var tween = create_tween()
		# Diminui o volume para silêncio (-80dB) em 1.5 segundos
		tween.tween_property(musica_fundo, "volume_db", -80, 1.5)
		# Quando o som sumir, paramos o player de vez
		tween.finished.connect(func(): musica_fundo.stop())
	
	if som_vitoria: som_vitoria.play()
	
	question_label.text = txt
	var btn = Button.new()
	btn.name = "RestartBtn"
	btn.text = "JOGAR NOVAMENTE"
	btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(btn)
	btn.pressed.connect(func(): if multiplayer.is_server(): reset_game_logic.rpc())
	create_back_to_menu_button()

@rpc("authority", "call_local")
func reset_game_logic():
	is_game_over = false
	value = 50.0
	timer = 60
	
	# Garante que o som de vitória pare se o jogador for rápido
	if som_vitoria: som_vitoria.stop()
	
	# Remove os botões de fim de jogo da tela
	if has_node("RestartBtn"): get_node("RestartBtn").queue_free()
	if has_node("BackToMenuBtn"): get_node("BackToMenuBtn").queue_free() # Adicione esta linha
	
	update_bar()
	
	# Reativa a visibilidade da interface de jogo (incluindo o teclado)
	set_ui_visibility(true) 
	
	if multiplayer.is_server():
		generate_new_question()
		start_timer()
		start_game()
		
func create_back_to_menu_button():
	var btn_menu = Button.new()
	btn_menu.name = "BackToMenuBtn"
	btn_menu.text = "SAIR PARA O MENU"
	btn_menu.custom_minimum_size = Vector2(300, 80)
	btn_menu.modulate = Color(1, 0.5, 0.5) # Deixa o botão avermelhado
	add_child(btn_menu)
	
	btn_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	btn_menu.position.y -= 600 # Fica abaixo do botão "Jogar Novamente"
	btn_menu.position.x -= 200 # Move o botão para a esquerda (aumente o número para mover mais)
	
	btn_menu.pressed.connect(_on_back_to_menu_pressed)
	
func resetar_para_menu():

	# 🔹 Reseta variáveis do jogo
	is_game_over = false
	value = 50.0
	timer = 60
	timer_label.text = "Tempo: 60"

	# 🔹 Limpa textos
	question_label.text = ""
	team1_input.text = ""
	team2_input.text = ""

	# 🔹 Fecha multiplayer corretamente
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	peer = ENetMultiplayerPeer.new()

	# 🔹 Remove botões criados dinamicamente
	if has_node("RestartBtn"):
		get_node("RestartBtn").queue_free()

	if has_node("BackToMenuBtn"):
		get_node("BackToMenuBtn").queue_free()

	# 🔹 Reativa botões do menu
	host_button.disabled = false
	join_button.disabled = false

	# 🔹 Garante layout limpo
	menu_inicial.visible = true
	arena_de_jogo.visible = false
	menu_inicial.move_to_front()  # força ficar por cima

	update_bar()
	
func _on_back_to_menu_pressed():

	# Para sons
	if musica_fundo:
		musica_fundo.stop()

	if som_vitoria:
		som_vitoria.stop()

	resetar_para_menu()
	
# Esta função é chamada automaticamente pelo Godot quando alguém conecta
func _on_player_connected(id):
	print("Jogador conectado: ", id)
	# Agora que o oponente chegou, limpamos a tela de espera
	$ArenaDeJogo/WaitingLabel.visible = false
	# E mostramos os elementos reais do jogo
	bar_bg.visible = true
	question_label.visible = true
	timer_label.visible = true
	if keypad_container: keypad_container.visible = true
	
