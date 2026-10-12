"""Add small high-contrast scene captions to a captured demo walkthrough."""

import argparse
import json
import shutil
import subprocess
from pathlib import Path


def timestamp(seconds, precision):
    factor = 10**precision
    ticks = round(seconds * factor)
    seconds, fraction = divmod(ticks, factor)
    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    separator = ',' if precision == 3 else '.'
    return f'{hours:02}:{minutes:02}:{seconds:02}{separator}{fraction:0{precision}}'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path, help='Capture output directory')
    args = parser.parse_args()
    directory = args.directory.resolve()
    video = directory / 'mediflow-demo.mp4'
    chapters = json.loads((directory / 'chapters.json').read_text())
    duration = float(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
        '-of', 'default=nw=1:nk=1', str(video),
    ]))
    header = '''[Script Info]
ScriptType: v4.00+
PlayResX: 720
PlayResY: 1280
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Roboto,25,&H00FFFFFF,&H00FFFFFF,&H182A170F,&H182A170F,0,0,0,0,100,100,0,0,3,6,0,2,34,34,26,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
    ass, srt = [], []
    for index, chapter in enumerate(chapters):
        end = chapters[index + 1]['seconds'] - 0.05 if index + 1 < len(chapters) else duration
        label = 'MediFlow Pro · Clinic demo' if index == 0 else chapter['label']
        # Captions are plain text; scene labels cannot insert ASS formatting.
        label = label.replace('{', '').replace('}', '').replace('\\', '').replace('\n', ' ')
        ass.append(f"Dialogue: 0,{timestamp(chapter['seconds'], 2)},{timestamp(end, 2)},Default,,0,0,0,,{label}")
        srt.append(f"{index + 1}\n{timestamp(chapter['seconds'], 3)} --> {timestamp(end, 3)}\n{label}\n")
    (directory / 'mediflow-demo.ass').write_text(header + '\n'.join(ass) + '\n')
    (directory / 'mediflow-demo.srt').write_text('\n'.join(srt))
    fonts = directory / 'caption-fonts'
    fonts.mkdir(exist_ok=True)
    shutil.copy2(Path(__file__).resolve().parent.parent / 'assets/fonts/Roboto.ttf', fonts / 'Roboto.ttf')
    # Relative filter paths avoid escaping user-selected export directories.
    subprocess.run([
        'ffmpeg', '-y', '-loglevel', 'error', '-i', 'mediflow-demo.mp4',
        '-vf', 'scale=666:1184,pad=720:1280:27:0:color=0xF8FAFC,subtitles=mediflow-demo.ass:fontsdir=caption-fonts',
        '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart', 'mediflow-demo-captioned.mp4',
    ], cwd=directory, check=True)
    print(f'Captioned walkthrough saved: {directory / "mediflow-demo-captioned.mp4"}')


if __name__ == '__main__':
    main()
