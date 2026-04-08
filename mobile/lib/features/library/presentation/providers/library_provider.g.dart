// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$librariesHash() => r'56e6dd74e88a993a22708712be4cca212361a300';

/// See also [libraries].
@ProviderFor(libraries)
final librariesProvider =
    AutoDisposeFutureProvider<List<LibraryModel>>.internal(
  libraries,
  name: r'librariesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$librariesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LibrariesRef = AutoDisposeFutureProviderRef<List<LibraryModel>>;
String _$refreshStatusHash() => r'1cf14266a3f73bcfc92ce72c84fd978da8806bf1';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 媒体库刷新状态轮询（Stream）
///
/// Copied from [refreshStatus].
@ProviderFor(refreshStatus)
const refreshStatusProvider = RefreshStatusFamily();

/// 媒体库刷新状态轮询（Stream）
///
/// Copied from [refreshStatus].
class RefreshStatusFamily extends Family<AsyncValue<LibraryModel>> {
  /// 媒体库刷新状态轮询（Stream）
  ///
  /// Copied from [refreshStatus].
  const RefreshStatusFamily();

  /// 媒体库刷新状态轮询（Stream）
  ///
  /// Copied from [refreshStatus].
  RefreshStatusProvider call(
    String libraryId,
  ) {
    return RefreshStatusProvider(
      libraryId,
    );
  }

  @override
  RefreshStatusProvider getProviderOverride(
    covariant RefreshStatusProvider provider,
  ) {
    return call(
      provider.libraryId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'refreshStatusProvider';
}

/// 媒体库刷新状态轮询（Stream）
///
/// Copied from [refreshStatus].
class RefreshStatusProvider extends AutoDisposeStreamProvider<LibraryModel> {
  /// 媒体库刷新状态轮询（Stream）
  ///
  /// Copied from [refreshStatus].
  RefreshStatusProvider(
    String libraryId,
  ) : this._internal(
          (ref) => refreshStatus(
            ref as RefreshStatusRef,
            libraryId,
          ),
          from: refreshStatusProvider,
          name: r'refreshStatusProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$refreshStatusHash,
          dependencies: RefreshStatusFamily._dependencies,
          allTransitiveDependencies:
              RefreshStatusFamily._allTransitiveDependencies,
          libraryId: libraryId,
        );

  RefreshStatusProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.libraryId,
  }) : super.internal();

  final String libraryId;

  @override
  Override overrideWith(
    Stream<LibraryModel> Function(RefreshStatusRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RefreshStatusProvider._internal(
        (ref) => create(ref as RefreshStatusRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        libraryId: libraryId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<LibraryModel> createElement() {
    return _RefreshStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RefreshStatusProvider && other.libraryId == libraryId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, libraryId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin RefreshStatusRef on AutoDisposeStreamProviderRef<LibraryModel> {
  /// The parameter `libraryId` of this provider.
  String get libraryId;
}

class _RefreshStatusProviderElement
    extends AutoDisposeStreamProviderElement<LibraryModel>
    with RefreshStatusRef {
  _RefreshStatusProviderElement(super.provider);

  @override
  String get libraryId => (origin as RefreshStatusProvider).libraryId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
