extends Control

signal host_requested
signal join_requested(ip)

# Caminhos corrigidos conforme sua árvore de cenas (image_315f61)
@onready var ip_input = $VBoxContainer/IPInput
@onready var label_status = $VBoxContainer/IP # Nome atualizado para "IP"
@onready var host_button = $VBoxContainer/HostButton
@onready var join_button = $VBoxContainer/JoinButton
@onready var game_title = $VBoxContainer/IP # Usando o Label de IP para o efeito de balanço

func _ready():
	# Efeito de balanço (Opcional, pode remover se preferir o título parado)
	if game_title:
		var tween = create_tween().set_loops()
		tween.tween_property(game_title, "rotation_degrees", 2.0, 1.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(game_title, "rotation_degrees", -2.0, 1.5).set_trans(Tween.TRANS_SINE)
	
	exibir_ip_local()

func exibir_ip_local():
	var meu_ip = ""
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			meu_ip = ip
			break
	label_status.text = "🌐 Seu IP: " + (meu_ip if meu_ip != "" else "Buscando...")

# IMPORTANTE: No Editor, conecte o sinal 'pressed' do HostButton a esta função
func _on_host_button_pressed():
	print("Botão Host clicado no MenuInicial!") # <--- Adicione este print
	host_button.disabled = true
	join_button.disabled = true
	emit_signal("host_requested")
	print("Sinal host_requested emitido!") # <--- Adicione este também
# IMPORTANTE: No Editor, conecte o sinal 'pressed' do JoinButton a esta função
func _on_join_button_pressed():
	var ip = ip_input.text.strip_edges()
	emit_signal("join_requested", ip if ip != "" else "127.0.0.1")
