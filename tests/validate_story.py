"""Validate the authored campaign graph and asset references without Godot."""
# Kiểm tra tĩnh năm file truyện bằng Python, không cần mở Godot.
# Chạy từ thư mục project: python tests/validate_story.py; assert thất bại làm tiến trình báo lỗi.
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


# Kiểm tra ID/đích cảnh, asset, đáp án câu đố, mốc và khả năng đi tới mọi cảnh trong đồ thị.
# Đây là kiểm tra liên kết tĩnh, không chứng minh các điều kiện when/requires có thể đạt khi chơi.
def validate():
    total_scenes = total_lines = 0
    puzzle_ids = set()
    checkpoints = set()
    portraits = set()
    characters = {'Kiên': 'Kien', 'Thư': 'Thu', 'Vy': 'Vy', 'Vy trong ghi âm': 'Vy'}
    music = json.loads((ROOT / 'data/audio/music.json').read_text(encoding='utf-8'))
    tracks = music['tracks']
    assert music['crossfade_seconds'] >= 0
    assert set(tracks) == {'BGM_DAILY', 'BGM_DREAM', 'BGM_INVESTIGATION',
                           'BGM_GRIEF', 'BGM_TRUST', 'BGM_FINAL_ROAD',
                           *(f'BGM_ENDING_E{i}' for i in range(1, 5))}
    for track_id, track in tracks.items():
        assert isinstance(track['loop'], bool), track_id
        if track['path']:
            assert (ROOT / track['path'].removeprefix('res://')).is_file(), track_id
    expected_ends = {1: {'c1s5'}, 2: {'c2s5'}, 3: {'c3truth'},
                     4: {'c4s2'}, 5: {'e1', 'e2', 'e3', 'e4'}}

    # Duyệt cả object/mảng lồng nhau; mỗi chuỗi res:// phải trỏ tới file đang có trong project.
    def assets(value):
        if isinstance(value, dict):
            for item in value.values():
                assets(item)
        elif isinstance(value, list):
            for item in value:
                assets(item)
        elif isinstance(value, str) and value.startswith('res://'):
            assert (ROOT / value.removeprefix('res://')).is_file(), value

    for chapter in range(1, 6):
        path = ROOT / f'data/story/chapter_{chapter:02}.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        assets(data)
        scenes = data['episodes'][0]['scenes']
        ids = {scene['id'] for scene in scenes}
        assert len(ids) == len(scenes), f'Duplicate scene ID: {path}'
        assert len({scene['location'] for scene in scenes}) == len(scenes), 'History requires unique scene locations'
        graph = {}
        for scene in scenes:
            total_scenes += 1
            lines = scene['dialogues']
            total_lines += len(lines)
            assert lines, f'Empty scene: {scene["id"]}'
            if 'checkpoint' in scene:
                checkpoints.add(scene['checkpoint'])
            # Cạnh chuyển cảnh gồm next và choices.go; đích rỗng là kết thúc chương.
            target = scene.get('next', '')
            edges = {target} if isinstance(target, str) else {b['go'] for b in target}
            edges.discard('')
            for line in lines:
                if line.get('speaker') in characters:
                    name = characters[line['speaker']]
                    expected = {f'res://assets/avatars/Avatar_{name}{suffix}.png'
                                for suffix in ['', '_NoE', '_Sad', '_Sudden']}
                    assert line.get('avatar') in expected, (scene['id'], line)
                    portraits.add(line['avatar'])
                for choice in line.get('choices', []):
                    assert choice.get('avatar') in {
                        f'res://assets/avatars/Avatar_Kien{suffix}.png'
                        for suffix in ['', '_NoE', '_Sad', '_Sudden']}, (scene['id'], choice)
                    if 'go' in choice:
                        edges.add(choice['go'])
                    if choice.get('set', {}).get('ending_id') in ['E1', 'E2', 'E3']:
                        assert choice.get('confirm'), 'Ending requires confirmation'
                # Câu đố phải có ID duy nhất toàn chiến dịch và đáp án nằm trong chỉ số items.
                events = line.get('events', [line['event']] if 'event' in line else [])
                for event in events:
                    if event['type'] == 'change_music':
                        assert event['id'] in tracks, event
                        assert 'path' not in event, 'Campaign cues must use configured IDs'
                    if event['type'] != 'minigame':
                        continue
                    assert event['id'] not in puzzle_ids, event['id']
                    puzzle_ids.add(event['id'])
                    config = event['config']
                    assert config['answer'] and len(set(config['answer'])) == len(config['answer'])
                    assert all(0 <= index < len(config['items']) for index in config['answer'])
            assert edges <= ids, f'Broken targets in {scene["id"]}: {edges - ids}'
            graph[scene['id']] = edges
        # Duyệt từ cảnh đầu, gộp mọi nhánh điều kiện để tìm cảnh không có đường dẫn tới.
        reachable, pending = set(), [scenes[0]['id']]
        while pending:
            current = pending.pop()
            if current not in reachable:
                reachable.add(current)
                pending.extend(graph[current])
        assert reachable == ids, f'Unreachable scenes: {ids - reachable}'
        # Cảnh không có cạnh đi tiếp phải đúng tập kết thúc dự kiến, tránh cụt nhánh ngoài ý muốn.
        assert {id for id, edges in graph.items() if not edges} == expected_ends[chapter]
    assert checkpoints == {'preparation', 'final_choice'}
    assert len(portraits) == 12, 'Campaign must use all twelve authored expressions'
    print(f'STORY DATA: {total_scenes} reachable scenes, {total_lines} lines, '
          f'{len(puzzle_ids)} puzzles; all targets and assets valid')
    print('MUSIC: unassigned IDs: ' + ', '.join(key for key, value in tracks.items() if not value['path']))


if __name__ == '__main__':
    validate()
