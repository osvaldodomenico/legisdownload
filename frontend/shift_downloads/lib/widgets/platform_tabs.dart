import 'package:flutter/material.dart';

const _platforms = [
  {'id': 'youtube',   'label': '▶ YT',  'hint': 'youtube.com/watch?v=...'},
  {'id': 'instagram', 'label': '◉ IG',  'hint': 'instagram.com/reel/...'},
  {'id': 'tiktok',    'label': '♪ TK',  'hint': 'tiktok.com/@user/video/...'},
  {'id': 'vimeo',     'label': '▣ VM',  'hint': 'vimeo.com/...'},
  {'id': 'facebook',  'label': 'f FB',  'hint': 'facebook.com/video/...'},
];

const platformTabs = [
  Tab(text: '▶ YT'),
  Tab(text: '◉ IG'),
  Tab(text: '♪ TK'),
  Tab(text: '▣ VM'),
  Tab(text: 'f FB'),
];

String platformHint(int index) => _platforms[index]['hint']!;
String platformId(int index) => _platforms[index]['id']!;
