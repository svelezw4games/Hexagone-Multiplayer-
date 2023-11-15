extends TCPServer

const REPLY_HEADER_OK = "HTTP/1.1 {{CODE}} OK\r\nServer: TCPServer\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n"

class TCPClient:
	var tcp : StreamPeerTCP
	var read_chunk = 64
	var request_over = false
	var chunks = []
	var response_chunks = []
	var request_bytes := PackedByteArray()
	var request_method = ""
	var request_code := 200
	var request : String
	var sn = "\n".to_ascii_buffer()[0]
	var sr = "\r".to_ascii_buffer()[0]

	func _init(p_tcp : StreamPeerTCP):
		tcp = p_tcp

	func _parse_request():
		var base = request.split("\r\n", true, 1)
		var split = request.split(" ", true, 3)
		request_method = split[0] if split.size() else "ERROR"
		if split.size() > 1 and split[1].substr(1).is_valid_int():
			request_code = split[1].to_int()

	func poll():
		tcp.poll()
		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return
		if not request_over:
			while tcp.get_available_bytes():
				var data = tcp.get_partial_data(1)
				if data[0] != OK:
					tcp.disconnect_from_host()
					return
				request_bytes.append_array(data[1])
				var s = request_bytes.size()
				var rb = request_bytes
				if s >= 4 and rb[s-4] == sr and rb[s-3] == sn and rb[s-2] == sr and rb[s-1] == sn:
					request = request_bytes.get_string_from_utf8()
					request_over = true
		elif request_method.is_empty():
			_parse_request()
			if request_code == -1:
				tcp.disconnect_from_host()
				return
			tcp.put_data(REPLY_HEADER_OK.replace("{{CODE}}", str(request_code)).to_utf8_buffer())
		else:
			tcp.put_data(request_method.to_utf8_buffer())
			tcp.disconnect_from_host()


var clients = []

func poll():
	if is_connection_available():
		clients.append(TCPClient.new(take_connection()))
	var remove = []
	for c in clients:
		c.poll()
		var status = c.tcp.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED and status != StreamPeerTCP.STATUS_CONNECTING:
			remove.append(c)
	for r in remove:
		clients.erase(r)
