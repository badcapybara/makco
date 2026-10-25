import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'catalog.dart';
import 'recents.dart';

const _keep = Object();

class RideState {
  final Station? from;
  final Station? to;
  final int quantity;
  final bool searching;
  final List<Quote> quotes;
  final String? searchId;
  final String? error;
  final String? confirmingQuoteId;

  const RideState({
    this.from,
    this.to,
    this.quantity = 1,
    this.searching = false,
    this.quotes = const [],
    this.searchId,
    this.error,
    this.confirmingQuoteId,
  });

  bool get ready => from != null && to != null;

  RideState copyWith({
    Object? from = _keep,
    Object? to = _keep,
    int? quantity,
    bool? searching,
    List<Quote>? quotes,
    Object? searchId = _keep,
    Object? error = _keep,
    Object? confirmingQuoteId = _keep,
  }) {
    return RideState(
      from: identical(from, _keep) ? this.from : from as Station?,
      to: identical(to, _keep) ? this.to : to as Station?,
      quantity: quantity ?? this.quantity,
      searching: searching ?? this.searching,
      quotes: quotes ?? this.quotes,
      searchId: identical(searchId, _keep)
          ? this.searchId
          : searchId as String?,
      error: identical(error, _keep) ? this.error : error as String?,
      confirmingQuoteId: identical(confirmingQuoteId, _keep)
          ? this.confirmingQuoteId
          : confirmingQuoteId as String?,
    );
  }
}

/// Drives the one-screen booking surface: stations, live fares, confirmation.
class RideController extends Notifier<RideState> {
  int _seq = 0;

  @override
  RideState build() => const RideState();

  void pickFrom(Station station) {
    final to = state.to?.code == station.code ? null : state.to;
    state = state.copyWith(from: station, to: to);
    _maybeSearch();
  }

  void pickTo(Station station) {
    final from = state.from?.code == station.code ? null : state.from;
    state = state.copyWith(from: from, to: station);
    _maybeSearch();
  }

  void swap() {
    state = state.copyWith(from: state.to, to: state.from);
    _maybeSearch();
  }

  void setQuantity(int value) {
    final quantity = value.clamp(1, 10);
    if (quantity == state.quantity) return;
    state = state.copyWith(quantity: quantity);
    if (state.ready) unawaited(search());
  }

  void reset() {
    _seq++;
    state = RideState(quantity: state.quantity);
  }

  /// Replays a saved recent route and fetches fresh fares.
  void loadTrip(RecentTrip trip) {
    state = RideState(
      from: Station(code: trip.fromCode, name: trip.fromName),
      to: Station(code: trip.toCode, name: trip.toName),
      quantity: trip.quantity,
    );
    unawaited(search());
  }

  void _maybeSearch() {
    if (state.ready) {
      unawaited(search());
    } else {
      _seq++;
      state = state.copyWith(
        searching: false,
        quotes: const [],
        searchId: null,
        error: null,
      );
    }
  }

  Future<void> search() async {
    final from = state.from;
    final to = state.to;
    if (from == null || to == null) return;

    final seq = ++_seq;
    state = state.copyWith(
      searching: true,
      quotes: const [],
      searchId: null,
      error: null,
    );

    try {
      final body = await Api.search(
        TransitMode.metro,
        from.code,
        to.code,
        state.quantity,
      );
      final searchId =
          (body['searchId'] ??
                  (body['search'] as Map<String, dynamic>?)?['searchId'])
              ?.toString();
      if (searchId == null || searchId.isEmpty) {
        throw ApiException('No fares were found for that trip.');
      }

      for (var attempt = 0; attempt < 7; attempt++) {
        await Future<void>.delayed(
          Duration(milliseconds: attempt == 0 ? 500 : 1200),
        );
        if (seq != _seq) return;
        final quotes = await Api.quote(searchId, mode: TransitMode.metro.key);
        if (seq != _seq) return;
        if (quotes.isNotEmpty) {
          state = state.copyWith(
            searching: false,
            quotes: quotes,
            searchId: searchId,
            error: null,
          );
          return;
        }
      }

      state = state.copyWith(
        searching: false,
        searchId: searchId,
        error: 'No fares yet for this route. Try again in a moment.',
      );
    } on ApiException catch (e) {
      if (seq == _seq) {
        state = state.copyWith(searching: false, error: e.message);
      }
    } catch (_) {
      if (seq == _seq) {
        state = state.copyWith(
          searching: false,
          error: 'Could not fetch fares. Check your connection.',
        );
      }
    }
  }

  Future<Booking> confirm(Quote quote) async {
    final from = state.from;
    final to = state.to;
    if (from == null || to == null) {
      throw ApiException('Pick your start and stop first.');
    }

    state = state.copyWith(confirmingQuoteId: quote.quoteId, error: null);
    try {
      final booking = await Api.confirm(
        quote.quoteId,
        state.quantity,
        mode: TransitMode.metro.key,
      );
      await ref
          .read(recentsProvider.notifier)
          .add(
            RecentTrip(
              fromCode: from.code,
              fromName: from.name,
              toCode: to.code,
              toName: to.name,
              quantity: state.quantity,
            ),
          );
      ref.invalidate(ticketsProvider);
      return booking;
    } finally {
      state = state.copyWith(confirmingQuoteId: null);
    }
  }
}

final rideProvider = NotifierProvider<RideController, RideState>(
  RideController.new,
);
