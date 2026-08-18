/// Payloads shaped exactly like the ones the FastAPI server emits.
///
/// The READY frame is hand-built server-side (`gateway/router.py`
/// `_build_ready_payload`) rather than dumped from the pydantic schemas, so its
/// `user` and `channels` entries carry no `created_at` even though the REST
/// views of the same objects do. These fixtures keep that difference visible;
/// a fuller set captured from a live server lands with the contract tests.
library;

const readyFrame = <String, dynamic>{
  'op': 'READY',
  'data': {
    'user': {
      'id': '0d1a4e8e-0d9f-4a5f-9f6f-2f6f5a1c0b11',
      'username': 'marcio',
      'is_admin': true,
    },
    'server': {
      'name': 'Campfire',
      'icon_url': null,
      'max_upload_bytes': 26214400,
    },
    'channels': [
      {
        'id': 'b3c1d2e3-0000-4000-8000-000000000001',
        'name': 'geral',
        'type': 'text',
        'position': 0,
      },
      {
        'id': 'b3c1d2e3-0000-4000-8000-000000000002',
        'name': 'fogueira',
        'type': 'voice',
        'position': 1,
      },
    ],
    'dms': [
      {
        'id': 'b3c1d2e3-0000-4000-8000-0000000000dd',
        'recipient': {
          'id': '0d1a4e8e-0d9f-4a5f-9f6f-2f6f5a1c0b22',
          'username': 'ana',
          'is_admin': false,
          'created_at': '2026-08-01T12:00:00Z',
        },
        'last_message_at': '2026-08-16T22:31:04.512000Z',
        'unread_count': 3,
      },
    ],
    'online_user_ids': ['0d1a4e8e-0d9f-4a5f-9f6f-2f6f5a1c0b22'],
    'voice_states': [
      {
        'user_id': '0d1a4e8e-0d9f-4a5f-9f6f-2f6f5a1c0b22',
        'username': 'ana',
        'channel_id': 'b3c1d2e3-0000-4000-8000-000000000002',
        'muted': false,
        'speaking': true,
      },
    ],
  },
};

/// `MESSAGE_CREATE` carries a full `MessageRead`, attachments and reply preview
/// included.
const messageCreateFrame = <String, dynamic>{
  'op': 'MESSAGE_CREATE',
  'data': {
    'id': 'aa000000-0000-4000-8000-000000000001',
    'channel_id': 'b3c1d2e3-0000-4000-8000-000000000001',
    'author': {
      'id': '0d1a4e8e-0d9f-4a5f-9f6f-2f6f5a1c0b22',
      'username': 'ana',
      'is_admin': false,
      'created_at': '2026-08-01T12:00:00Z',
    },
    'content': 'olha esse vídeo @marcio',
    'created_at': '2026-08-16T22:31:04.512000Z',
    'edited_at': null,
    'attachments': [
      {
        'id': 'cc000000-0000-4000-8000-000000000001',
        'filename': 'fogueira.mp4',
        'content_type': 'video/mp4',
        'size_bytes': 1048576,
        'url': '/api/uploads/cc000000-0000-4000-8000-000000000001',
        'created_at': '2026-08-16T22:31:00.000000Z',
      },
    ],
    'reply_to': {
      'id': 'aa000000-0000-4000-8000-000000000000',
      'author': {
        'id': '0d1a4e8e-0d9f-4a5f-9f6f-2f6f5a1c0b11',
        'username': 'marcio',
        'is_admin': true,
        'created_at': '2026-07-01T12:00:00Z',
      },
      'content': 'manda aí',
      'has_attachments': false,
    },
  },
};
