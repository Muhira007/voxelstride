extends RefCounted

# Stable IDs are save identities; display order, labels and categories may change safely.
const WORLD_IDS := ["classic","farm","valley","city"]
const CATEGORIES := ["Semua","Alam","Pedesaan","Perkotaan"]
const ENTRIES := [
	{"id":"city","name":"Kota Harmoni","category":"Perkotaan","size":384,"height":80,"generator":4,"path":"worlds/kota-harmoni.json","tag":"BARU · v0.5","color":"dcaa69","summary":"Gedung bertingkat, boulevard, taman kota, terminal, dan kendaraan.","detail":"Jelajahi distrik bisnis, pertokoan dan hunian. Mobil, bus, serta van meramaikan jalan; lalu lintas sederhana, belum bisa dikendarai.","art":"city"},
	{"id":"valley","name":"Lembah & Air Terjun","category":"Alam","size":384,"height":80,"generator":3,"path":"worlds/lembah-air-terjun.json","tag":"JELAJAH","color":"74b7b1","summary":"Bukit berhutan, sungai dan danau, desa lembah, serta kebun bertingkat.","detail":"Air terjun animasi 35 blok, jalur puncak, pondok hutan, menara pandang, dan 20 ternak. Air bersifat dekoratif, tanpa simulasi berenang.","art":"valley"},
	{"id":"farm","name":"Desa Pertanian","category":"Pedesaan","size":192,"height":40,"generator":2,"path":"worlds/desa-pertanian.json","tag":"BERSANTAI","color":"a9bd75","summary":"Enam rumah, ladang beririgasi, kebun apel, dan empat kandang ternak.","detail":"20 ternak berjalan di kandang. Ruang membangun terbuka di barat desa; belum ada sistem panen, pertumbuhan tanaman, atau breeding.","art":"farm"},
	{"id":"classic","name":"Dunia Klasik","category":"Alam","size":96,"height":40,"generator":1,"path":"world.json","tag":"ORISINAL","color":"a8b6d3","summary":"Bukit kecil, pepohonan, dan ruang kreatif. Dunia asli tetap tersedia.","detail":"Lingkungan voxel pertama dengan generator asli. Semua bangunan dan perubahan pada save klasik tetap berada di slot ini.","art":"classic"}
]

static func entry(id: String) -> Dictionary:
	for item in ENTRIES:
		if item["id"] == id: return item
	return {}

static func filtered(category: String = "Semua",query: String = "",source: Array = ENTRIES) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var needle := query.strip_edges().to_lower()
	for item in source:
		if category != "Semua" and item["category"] != category: continue
		if not needle.is_empty() and not (item["name"]+" "+item["id"]+" "+item["summary"]).to_lower().contains(needle): continue
		result.append(item)
	return result
