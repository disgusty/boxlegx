import 'package:flutter_test/flutter_test.dart';

import 'package:lxbox/services/builder/post_steps.dart';
import 'package:lxbox/services/settings_storage.dart' show RouteSitesConfig;

Map<String, dynamic> _config({String? routeFinal = 'vpn-1'}) => {
      'route': {
        'rules': [
          {'action': 'sniff'},
          {'protocol': 'dns', 'action': 'hijack-dns'},
          {'domain_suffix': ['ads.example'], 'action': 'reject'},
        ],
        'final': ?routeFinal,
      },
    };

List<dynamic> _rules(Map<String, dynamic> cfg) =>
    (cfg['route'] as Map<String, dynamic>)['rules'] as List<dynamic>;

void main() {
  group('applyRouteSites', () {
    test('off → no changes', () {
      final cfg = _config();
      applyRouteSites(cfg,
          const RouteSitesConfig(mode: 'off', sites: ['example.com']));
      expect(_rules(cfg), hasLength(3));
      expect(cfg['route']['final'], 'vpn-1');
    });

    test('empty list → no changes', () {
      final cfg = _config();
      applyRouteSites(cfg, const RouteSitesConfig(mode: 'deny', sites: []));
      expect(_rules(cfg), hasLength(3));
    });

    test('deny → direct rule after leading sniff/hijack-dns, final kept', () {
      final cfg = _config();
      applyRouteSites(
        cfg,
        const RouteSitesConfig(
            mode: 'deny', sites: ['example.com', '10.0.0.0/8', '1.2.3.4']),
      );
      final rules = _rules(cfg);
      expect(rules, hasLength(4));
      expect(rules[2], {
        'domain_suffix': ['example.com'],
        'ip_cidr': ['10.0.0.0/8', '1.2.3.4/32'],
        'action': 'route',
        'outbound': 'direct-out',
      });
      expect(rules[3]['action'], 'reject');
      expect(cfg['route']['final'], 'vpn-1');
    });

    test('allow → sites to previous final, final = direct-out', () {
      final cfg = _config(routeFinal: 'vpn-2');
      applyRouteSites(cfg,
          const RouteSitesConfig(mode: 'allow', sites: ['example.com']));
      expect(_rules(cfg)[2]['outbound'], 'vpn-2');
      expect(cfg['route']['final'], 'direct-out');
    });

    test('allow with final already direct-out → sites to vpn-1', () {
      final cfg = _config(routeFinal: 'direct-out');
      applyRouteSites(cfg,
          const RouteSitesConfig(mode: 'allow', sites: ['example.com']));
      expect(_rules(cfg)[2]['outbound'], 'vpn-1');
      expect(cfg['route']['final'], 'direct-out');
    });

    test('allow without final → sites to vpn-1', () {
      final cfg = _config(routeFinal: null);
      applyRouteSites(cfg,
          const RouteSitesConfig(mode: 'allow', sites: ['example.com']));
      expect(_rules(cfg)[2]['outbound'], 'vpn-1');
    });
  });

  group('RouteSitesConfig.normalize', () {
    test('URL → host', () {
      expect(RouteSitesConfig.normalize('https://www.Example.com:443/a?b'),
          'www.example.com');
      expect(RouteSitesConfig.normalize('*.example.com'), 'example.com');
      expect(RouteSitesConfig.normalize('.example.com.'), 'example.com');
      expect(RouteSitesConfig.normalize('example.com:8080'), 'example.com');
    });

    test('IP and CIDR kept', () {
      expect(RouteSitesConfig.normalize('10.0.0.0/8'), '10.0.0.0/8');
      expect(RouteSitesConfig.normalize('1.2.3.4:443'), '1.2.3.4');
      expect(RouteSitesConfig.normalize('2001:db8::/32'), '2001:db8::/32');
      expect(RouteSitesConfig.normalize('[2001:db8::1]:443'), '2001:db8::1');
    });

    test('garbage → null', () {
      expect(RouteSitesConfig.normalize(''), isNull);
      expect(RouteSitesConfig.normalize('not a site'), isNull);
      expect(RouteSitesConfig.normalize('300.1.1.1'), isNull);
    });
  });

  group('RouteSitesConfig.parseList', () {
    test('Amnezia JSON', () {
      expect(
        RouteSitesConfig.parseList(
            '[{"hostname":"example.com","ip":""},{"hostname":"","ip":"1.2.3.4"}]'),
        ['example.com', '1.2.3.4'],
      );
    });

    test('plain text with comments', () {
      expect(
        RouteSitesConfig.parseList('# list\nexample.com\n\nfoo.org, bar.net # x\n'),
        ['example.com', 'foo.org', 'bar.net'],
      );
    });

    test('export round-trips through import', () {
      const sites = ['example.com', '10.0.0.0/8'];
      expect(RouteSitesConfig.parseList(RouteSitesConfig.toAmneziaJson(sites)),
          sites);
    });
  });
}
