import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import 'network_chrome.dart';

class NetworkInterfacesSection extends StatelessWidget {
  const NetworkInterfacesSection({super.key, required this.interfaces});

  final List<NetworkInterface> interfaces;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const NetworkSectionTitle('Interfaces'),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120),
          child: interfaces.isEmpty
              ? const NetworkEmptyState(message: 'No interfaces found.')
              : ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final NetworkInterface interface in interfaces)
                      _NetworkInterfaceRow(interface: interface),
                  ],
                ),
        ),
      ],
    );
  }
}

class _NetworkInterfaceRow extends StatelessWidget {
  const _NetworkInterfaceRow({required this.interface});

  final NetworkInterface interface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      // A sunk well rather than an outlined card: `--st-well` over `--st-sink`.
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(6),
        child: DecoratedBox(
          decoration: const ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0x70010102), Color(0x66020305)],
            ),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
          child: Stack(
            children: <Widget>[
              // `inset 0 2px 4px oklch(0 0 0 / 0.6)`.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x99000000), Color(0x00000000)],
                      stops: <double>[0, 0.35],
                    ),
                  ),
                ),
              ),
              // `inset 0 -1px 0 oklch(1 0 0 / 0.05)`.
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: Color(0x0DFFFFFF),
                  child: SizedBox(height: 1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        interface.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: HyprTypography.compactMono.copyWith(
                          color: NetworkMenuColors.fg2,
                          fontSize: HyprTypography.size(11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 92,
                      child: Text(
                        interface.address ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: HyprTypography.compactMonoStrong.copyWith(
                          color: NetworkMenuColors.fg1,
                          fontSize: HyprTypography.size(11),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
