// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$directoryContentHash() => r'951cd07403acf1d083495ecbbc22bf94f3573360';

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

/// 当前目录的内容
///
/// Copied from [directoryContent].
@ProviderFor(directoryContent)
const directoryContentProvider = DirectoryContentFamily();

/// 当前目录的内容
///
/// Copied from [directoryContent].
class DirectoryContentFamily extends Family<AsyncValue<DirectoryContent>> {
  /// 当前目录的内容
  ///
  /// Copied from [directoryContent].
  const DirectoryContentFamily();

  /// 当前目录的内容
  ///
  /// Copied from [directoryContent].
  DirectoryContentProvider call(
    String libraryId,
    String path,
  ) {
    return DirectoryContentProvider(
      libraryId,
      path,
    );
  }

  @override
  DirectoryContentProvider getProviderOverride(
    covariant DirectoryContentProvider provider,
  ) {
    return call(
      provider.libraryId,
      provider.path,
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
  String? get name => r'directoryContentProvider';
}

/// 当前目录的内容
///
/// Copied from [directoryContent].
class DirectoryContentProvider
    extends AutoDisposeFutureProvider<DirectoryContent> {
  /// 当前目录的内容
  ///
  /// Copied from [directoryContent].
  DirectoryContentProvider(
    String libraryId,
    String path,
  ) : this._internal(
          (ref) => directoryContent(
            ref as DirectoryContentRef,
            libraryId,
            path,
          ),
          from: directoryContentProvider,
          name: r'directoryContentProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$directoryContentHash,
          dependencies: DirectoryContentFamily._dependencies,
          allTransitiveDependencies:
              DirectoryContentFamily._allTransitiveDependencies,
          libraryId: libraryId,
          path: path,
        );

  DirectoryContentProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.libraryId,
    required this.path,
  }) : super.internal();

  final String libraryId;
  final String path;

  @override
  Override overrideWith(
    FutureOr<DirectoryContent> Function(DirectoryContentRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DirectoryContentProvider._internal(
        (ref) => create(ref as DirectoryContentRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        libraryId: libraryId,
        path: path,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<DirectoryContent> createElement() {
    return _DirectoryContentProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DirectoryContentProvider &&
        other.libraryId == libraryId &&
        other.path == path;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, libraryId.hashCode);
    hash = _SystemHash.combine(hash, path.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin DirectoryContentRef on AutoDisposeFutureProviderRef<DirectoryContent> {
  /// The parameter `libraryId` of this provider.
  String get libraryId;

  /// The parameter `path` of this provider.
  String get path;
}

class _DirectoryContentProviderElement
    extends AutoDisposeFutureProviderElement<DirectoryContent>
    with DirectoryContentRef {
  _DirectoryContentProviderElement(super.provider);

  @override
  String get libraryId => (origin as DirectoryContentProvider).libraryId;
  @override
  String get path => (origin as DirectoryContentProvider).path;
}

String _$searchFilesHash() => r'c3d0719318c98ba5ce874b8f7a2928c3a3966a4f';

/// 搜索结果
///
/// Copied from [searchFiles].
@ProviderFor(searchFiles)
const searchFilesProvider = SearchFilesFamily();

/// 搜索结果
///
/// Copied from [searchFiles].
class SearchFilesFamily extends Family<AsyncValue<List<FileModel>>> {
  /// 搜索结果
  ///
  /// Copied from [searchFiles].
  const SearchFilesFamily();

  /// 搜索结果
  ///
  /// Copied from [searchFiles].
  SearchFilesProvider call(
    String libraryId,
    String keyword,
  ) {
    return SearchFilesProvider(
      libraryId,
      keyword,
    );
  }

  @override
  SearchFilesProvider getProviderOverride(
    covariant SearchFilesProvider provider,
  ) {
    return call(
      provider.libraryId,
      provider.keyword,
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
  String? get name => r'searchFilesProvider';
}

/// 搜索结果
///
/// Copied from [searchFiles].
class SearchFilesProvider extends AutoDisposeFutureProvider<List<FileModel>> {
  /// 搜索结果
  ///
  /// Copied from [searchFiles].
  SearchFilesProvider(
    String libraryId,
    String keyword,
  ) : this._internal(
          (ref) => searchFiles(
            ref as SearchFilesRef,
            libraryId,
            keyword,
          ),
          from: searchFilesProvider,
          name: r'searchFilesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$searchFilesHash,
          dependencies: SearchFilesFamily._dependencies,
          allTransitiveDependencies:
              SearchFilesFamily._allTransitiveDependencies,
          libraryId: libraryId,
          keyword: keyword,
        );

  SearchFilesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.libraryId,
    required this.keyword,
  }) : super.internal();

  final String libraryId;
  final String keyword;

  @override
  Override overrideWith(
    FutureOr<List<FileModel>> Function(SearchFilesRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SearchFilesProvider._internal(
        (ref) => create(ref as SearchFilesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        libraryId: libraryId,
        keyword: keyword,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<FileModel>> createElement() {
    return _SearchFilesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchFilesProvider &&
        other.libraryId == libraryId &&
        other.keyword == keyword;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, libraryId.hashCode);
    hash = _SystemHash.combine(hash, keyword.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SearchFilesRef on AutoDisposeFutureProviderRef<List<FileModel>> {
  /// The parameter `libraryId` of this provider.
  String get libraryId;

  /// The parameter `keyword` of this provider.
  String get keyword;
}

class _SearchFilesProviderElement
    extends AutoDisposeFutureProviderElement<List<FileModel>>
    with SearchFilesRef {
  _SearchFilesProviderElement(super.provider);

  @override
  String get libraryId => (origin as SearchFilesProvider).libraryId;
  @override
  String get keyword => (origin as SearchFilesProvider).keyword;
}

String _$currentPathHash() => r'd46563f6e89095fdfd1dccb76b9f7f592bd86f2b';

abstract class _$CurrentPath extends BuildlessAutoDisposeNotifier<String> {
  late final String libraryId;

  String build(
    String libraryId,
  );
}

/// 当前目录路径（页面内状态）
///
/// Copied from [CurrentPath].
@ProviderFor(CurrentPath)
const currentPathProvider = CurrentPathFamily();

/// 当前目录路径（页面内状态）
///
/// Copied from [CurrentPath].
class CurrentPathFamily extends Family<String> {
  /// 当前目录路径（页面内状态）
  ///
  /// Copied from [CurrentPath].
  const CurrentPathFamily();

  /// 当前目录路径（页面内状态）
  ///
  /// Copied from [CurrentPath].
  CurrentPathProvider call(
    String libraryId,
  ) {
    return CurrentPathProvider(
      libraryId,
    );
  }

  @override
  CurrentPathProvider getProviderOverride(
    covariant CurrentPathProvider provider,
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
  String? get name => r'currentPathProvider';
}

/// 当前目录路径（页面内状态）
///
/// Copied from [CurrentPath].
class CurrentPathProvider
    extends AutoDisposeNotifierProviderImpl<CurrentPath, String> {
  /// 当前目录路径（页面内状态）
  ///
  /// Copied from [CurrentPath].
  CurrentPathProvider(
    String libraryId,
  ) : this._internal(
          () => CurrentPath()..libraryId = libraryId,
          from: currentPathProvider,
          name: r'currentPathProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$currentPathHash,
          dependencies: CurrentPathFamily._dependencies,
          allTransitiveDependencies:
              CurrentPathFamily._allTransitiveDependencies,
          libraryId: libraryId,
        );

  CurrentPathProvider._internal(
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
  String runNotifierBuild(
    covariant CurrentPath notifier,
  ) {
    return notifier.build(
      libraryId,
    );
  }

  @override
  Override overrideWith(CurrentPath Function() create) {
    return ProviderOverride(
      origin: this,
      override: CurrentPathProvider._internal(
        () => create()..libraryId = libraryId,
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
  AutoDisposeNotifierProviderElement<CurrentPath, String> createElement() {
    return _CurrentPathProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CurrentPathProvider && other.libraryId == libraryId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, libraryId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin CurrentPathRef on AutoDisposeNotifierProviderRef<String> {
  /// The parameter `libraryId` of this provider.
  String get libraryId;
}

class _CurrentPathProviderElement
    extends AutoDisposeNotifierProviderElement<CurrentPath, String>
    with CurrentPathRef {
  _CurrentPathProviderElement(super.provider);

  @override
  String get libraryId => (origin as CurrentPathProvider).libraryId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
