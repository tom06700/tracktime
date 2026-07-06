// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ShowsTable extends Shows with TableInfo<$ShowsTable, Show> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posterMeta = const VerificationMeta('poster');
  @override
  late final GeneratedColumn<String> poster = GeneratedColumn<String>(
    'poster',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalEpisodesMeta = const VerificationMeta(
    'totalEpisodes',
  );
  @override
  late final GeneratedColumn<int> totalEpisodes = GeneratedColumn<int>(
    'total_episodes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonCountMeta = const VerificationMeta(
    'seasonCount',
  );
  @override
  late final GeneratedColumn<int> seasonCount = GeneratedColumn<int>(
    'season_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runtimeMeta = const VerificationMeta(
    'runtime',
  );
  @override
  late final GeneratedColumn<int> runtime = GeneratedColumn<int>(
    'runtime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(42),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _episodesSyncedAtMeta = const VerificationMeta(
    'episodesSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> episodesSyncedAt =
      GeneratedColumn<DateTime>(
        'episodes_synced_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    poster,
    totalEpisodes,
    seasonCount,
    runtime,
    status,
    addedAt,
    episodesSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shows';
  @override
  VerificationContext validateIntegrity(
    Insertable<Show> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('poster')) {
      context.handle(
        _posterMeta,
        poster.isAcceptableOrUnknown(data['poster']!, _posterMeta),
      );
    }
    if (data.containsKey('total_episodes')) {
      context.handle(
        _totalEpisodesMeta,
        totalEpisodes.isAcceptableOrUnknown(
          data['total_episodes']!,
          _totalEpisodesMeta,
        ),
      );
    }
    if (data.containsKey('season_count')) {
      context.handle(
        _seasonCountMeta,
        seasonCount.isAcceptableOrUnknown(
          data['season_count']!,
          _seasonCountMeta,
        ),
      );
    }
    if (data.containsKey('runtime')) {
      context.handle(
        _runtimeMeta,
        runtime.isAcceptableOrUnknown(data['runtime']!, _runtimeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('episodes_synced_at')) {
      context.handle(
        _episodesSyncedAtMeta,
        episodesSyncedAt.isAcceptableOrUnknown(
          data['episodes_synced_at']!,
          _episodesSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Show map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Show(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      poster: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster'],
      ),
      totalEpisodes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_episodes'],
      ),
      seasonCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season_count'],
      ),
      runtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}runtime'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      episodesSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}episodes_synced_at'],
      ),
    );
  }

  @override
  $ShowsTable createAlias(String alias) {
    return $ShowsTable(attachedDatabase, alias);
  }
}

class Show extends DataClass implements Insertable<Show> {
  final int id;
  final String name;
  final String? poster;
  final int? totalEpisodes;
  final int? seasonCount;
  final int runtime;
  final String? status;
  final DateTime addedAt;
  final DateTime? episodesSyncedAt;
  const Show({
    required this.id,
    required this.name,
    this.poster,
    this.totalEpisodes,
    this.seasonCount,
    required this.runtime,
    this.status,
    required this.addedAt,
    this.episodesSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || poster != null) {
      map['poster'] = Variable<String>(poster);
    }
    if (!nullToAbsent || totalEpisodes != null) {
      map['total_episodes'] = Variable<int>(totalEpisodes);
    }
    if (!nullToAbsent || seasonCount != null) {
      map['season_count'] = Variable<int>(seasonCount);
    }
    map['runtime'] = Variable<int>(runtime);
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || episodesSyncedAt != null) {
      map['episodes_synced_at'] = Variable<DateTime>(episodesSyncedAt);
    }
    return map;
  }

  ShowsCompanion toCompanion(bool nullToAbsent) {
    return ShowsCompanion(
      id: Value(id),
      name: Value(name),
      poster: poster == null && nullToAbsent
          ? const Value.absent()
          : Value(poster),
      totalEpisodes: totalEpisodes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalEpisodes),
      seasonCount: seasonCount == null && nullToAbsent
          ? const Value.absent()
          : Value(seasonCount),
      runtime: Value(runtime),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      addedAt: Value(addedAt),
      episodesSyncedAt: episodesSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(episodesSyncedAt),
    );
  }

  factory Show.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Show(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      poster: serializer.fromJson<String?>(json['poster']),
      totalEpisodes: serializer.fromJson<int?>(json['totalEpisodes']),
      seasonCount: serializer.fromJson<int?>(json['seasonCount']),
      runtime: serializer.fromJson<int>(json['runtime']),
      status: serializer.fromJson<String?>(json['status']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      episodesSyncedAt: serializer.fromJson<DateTime?>(
        json['episodesSyncedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'poster': serializer.toJson<String?>(poster),
      'totalEpisodes': serializer.toJson<int?>(totalEpisodes),
      'seasonCount': serializer.toJson<int?>(seasonCount),
      'runtime': serializer.toJson<int>(runtime),
      'status': serializer.toJson<String?>(status),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'episodesSyncedAt': serializer.toJson<DateTime?>(episodesSyncedAt),
    };
  }

  Show copyWith({
    int? id,
    String? name,
    Value<String?> poster = const Value.absent(),
    Value<int?> totalEpisodes = const Value.absent(),
    Value<int?> seasonCount = const Value.absent(),
    int? runtime,
    Value<String?> status = const Value.absent(),
    DateTime? addedAt,
    Value<DateTime?> episodesSyncedAt = const Value.absent(),
  }) => Show(
    id: id ?? this.id,
    name: name ?? this.name,
    poster: poster.present ? poster.value : this.poster,
    totalEpisodes: totalEpisodes.present
        ? totalEpisodes.value
        : this.totalEpisodes,
    seasonCount: seasonCount.present ? seasonCount.value : this.seasonCount,
    runtime: runtime ?? this.runtime,
    status: status.present ? status.value : this.status,
    addedAt: addedAt ?? this.addedAt,
    episodesSyncedAt: episodesSyncedAt.present
        ? episodesSyncedAt.value
        : this.episodesSyncedAt,
  );
  Show copyWithCompanion(ShowsCompanion data) {
    return Show(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      poster: data.poster.present ? data.poster.value : this.poster,
      totalEpisodes: data.totalEpisodes.present
          ? data.totalEpisodes.value
          : this.totalEpisodes,
      seasonCount: data.seasonCount.present
          ? data.seasonCount.value
          : this.seasonCount,
      runtime: data.runtime.present ? data.runtime.value : this.runtime,
      status: data.status.present ? data.status.value : this.status,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      episodesSyncedAt: data.episodesSyncedAt.present
          ? data.episodesSyncedAt.value
          : this.episodesSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Show(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('poster: $poster, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('seasonCount: $seasonCount, ')
          ..write('runtime: $runtime, ')
          ..write('status: $status, ')
          ..write('addedAt: $addedAt, ')
          ..write('episodesSyncedAt: $episodesSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    poster,
    totalEpisodes,
    seasonCount,
    runtime,
    status,
    addedAt,
    episodesSyncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Show &&
          other.id == this.id &&
          other.name == this.name &&
          other.poster == this.poster &&
          other.totalEpisodes == this.totalEpisodes &&
          other.seasonCount == this.seasonCount &&
          other.runtime == this.runtime &&
          other.status == this.status &&
          other.addedAt == this.addedAt &&
          other.episodesSyncedAt == this.episodesSyncedAt);
}

class ShowsCompanion extends UpdateCompanion<Show> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> poster;
  final Value<int?> totalEpisodes;
  final Value<int?> seasonCount;
  final Value<int> runtime;
  final Value<String?> status;
  final Value<DateTime> addedAt;
  final Value<DateTime?> episodesSyncedAt;
  const ShowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.poster = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.seasonCount = const Value.absent(),
    this.runtime = const Value.absent(),
    this.status = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.episodesSyncedAt = const Value.absent(),
  });
  ShowsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.poster = const Value.absent(),
    this.totalEpisodes = const Value.absent(),
    this.seasonCount = const Value.absent(),
    this.runtime = const Value.absent(),
    this.status = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.episodesSyncedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Show> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? poster,
    Expression<int>? totalEpisodes,
    Expression<int>? seasonCount,
    Expression<int>? runtime,
    Expression<String>? status,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? episodesSyncedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (poster != null) 'poster': poster,
      if (totalEpisodes != null) 'total_episodes': totalEpisodes,
      if (seasonCount != null) 'season_count': seasonCount,
      if (runtime != null) 'runtime': runtime,
      if (status != null) 'status': status,
      if (addedAt != null) 'added_at': addedAt,
      if (episodesSyncedAt != null) 'episodes_synced_at': episodesSyncedAt,
    });
  }

  ShowsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? poster,
    Value<int?>? totalEpisodes,
    Value<int?>? seasonCount,
    Value<int>? runtime,
    Value<String?>? status,
    Value<DateTime>? addedAt,
    Value<DateTime?>? episodesSyncedAt,
  }) {
    return ShowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      poster: poster ?? this.poster,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      seasonCount: seasonCount ?? this.seasonCount,
      runtime: runtime ?? this.runtime,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      episodesSyncedAt: episodesSyncedAt ?? this.episodesSyncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (poster.present) {
      map['poster'] = Variable<String>(poster.value);
    }
    if (totalEpisodes.present) {
      map['total_episodes'] = Variable<int>(totalEpisodes.value);
    }
    if (seasonCount.present) {
      map['season_count'] = Variable<int>(seasonCount.value);
    }
    if (runtime.present) {
      map['runtime'] = Variable<int>(runtime.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (episodesSyncedAt.present) {
      map['episodes_synced_at'] = Variable<DateTime>(episodesSyncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('poster: $poster, ')
          ..write('totalEpisodes: $totalEpisodes, ')
          ..write('seasonCount: $seasonCount, ')
          ..write('runtime: $runtime, ')
          ..write('status: $status, ')
          ..write('addedAt: $addedAt, ')
          ..write('episodesSyncedAt: $episodesSyncedAt')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes with TableInfo<$EpisodesTable, Episode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _showIdMeta = const VerificationMeta('showId');
  @override
  late final GeneratedColumn<int> showId = GeneratedColumn<int>(
    'show_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stillMeta = const VerificationMeta('still');
  @override
  late final GeneratedColumn<String> still = GeneratedColumn<String>(
    'still',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _airDateMeta = const VerificationMeta(
    'airDate',
  );
  @override
  late final GeneratedColumn<DateTime> airDate = GeneratedColumn<DateTime>(
    'air_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    showId,
    season,
    episode,
    name,
    still,
    airDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Episode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('show_id')) {
      context.handle(
        _showIdMeta,
        showId.isAcceptableOrUnknown(data['show_id']!, _showIdMeta),
      );
    } else if (isInserting) {
      context.missing(_showIdMeta);
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    } else if (isInserting) {
      context.missing(_seasonMeta);
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('still')) {
      context.handle(
        _stillMeta,
        still.isAcceptableOrUnknown(data['still']!, _stillMeta),
      );
    }
    if (data.containsKey('air_date')) {
      context.handle(
        _airDateMeta,
        airDate.isAcceptableOrUnknown(data['air_date']!, _airDateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {showId, season, episode};
  @override
  Episode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Episode(
      showId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}show_id'],
      )!,
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      )!,
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      still: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}still'],
      ),
      airDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}air_date'],
      ),
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class Episode extends DataClass implements Insertable<Episode> {
  final int showId;
  final int season;
  final int episode;
  final String? name;
  final String? still;
  final DateTime? airDate;
  const Episode({
    required this.showId,
    required this.season,
    required this.episode,
    this.name,
    this.still,
    this.airDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['show_id'] = Variable<int>(showId);
    map['season'] = Variable<int>(season);
    map['episode'] = Variable<int>(episode);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || still != null) {
      map['still'] = Variable<String>(still);
    }
    if (!nullToAbsent || airDate != null) {
      map['air_date'] = Variable<DateTime>(airDate);
    }
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      showId: Value(showId),
      season: Value(season),
      episode: Value(episode),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      still: still == null && nullToAbsent
          ? const Value.absent()
          : Value(still),
      airDate: airDate == null && nullToAbsent
          ? const Value.absent()
          : Value(airDate),
    );
  }

  factory Episode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Episode(
      showId: serializer.fromJson<int>(json['showId']),
      season: serializer.fromJson<int>(json['season']),
      episode: serializer.fromJson<int>(json['episode']),
      name: serializer.fromJson<String?>(json['name']),
      still: serializer.fromJson<String?>(json['still']),
      airDate: serializer.fromJson<DateTime?>(json['airDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'showId': serializer.toJson<int>(showId),
      'season': serializer.toJson<int>(season),
      'episode': serializer.toJson<int>(episode),
      'name': serializer.toJson<String?>(name),
      'still': serializer.toJson<String?>(still),
      'airDate': serializer.toJson<DateTime?>(airDate),
    };
  }

  Episode copyWith({
    int? showId,
    int? season,
    int? episode,
    Value<String?> name = const Value.absent(),
    Value<String?> still = const Value.absent(),
    Value<DateTime?> airDate = const Value.absent(),
  }) => Episode(
    showId: showId ?? this.showId,
    season: season ?? this.season,
    episode: episode ?? this.episode,
    name: name.present ? name.value : this.name,
    still: still.present ? still.value : this.still,
    airDate: airDate.present ? airDate.value : this.airDate,
  );
  Episode copyWithCompanion(EpisodesCompanion data) {
    return Episode(
      showId: data.showId.present ? data.showId.value : this.showId,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      name: data.name.present ? data.name.value : this.name,
      still: data.still.present ? data.still.value : this.still,
      airDate: data.airDate.present ? data.airDate.value : this.airDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Episode(')
          ..write('showId: $showId, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('name: $name, ')
          ..write('still: $still, ')
          ..write('airDate: $airDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(showId, season, episode, name, still, airDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Episode &&
          other.showId == this.showId &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.name == this.name &&
          other.still == this.still &&
          other.airDate == this.airDate);
}

class EpisodesCompanion extends UpdateCompanion<Episode> {
  final Value<int> showId;
  final Value<int> season;
  final Value<int> episode;
  final Value<String?> name;
  final Value<String?> still;
  final Value<DateTime?> airDate;
  final Value<int> rowid;
  const EpisodesCompanion({
    this.showId = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.name = const Value.absent(),
    this.still = const Value.absent(),
    this.airDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodesCompanion.insert({
    required int showId,
    required int season,
    required int episode,
    this.name = const Value.absent(),
    this.still = const Value.absent(),
    this.airDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : showId = Value(showId),
       season = Value(season),
       episode = Value(episode);
  static Insertable<Episode> custom({
    Expression<int>? showId,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<String>? name,
    Expression<String>? still,
    Expression<DateTime>? airDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (showId != null) 'show_id': showId,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (name != null) 'name': name,
      if (still != null) 'still': still,
      if (airDate != null) 'air_date': airDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodesCompanion copyWith({
    Value<int>? showId,
    Value<int>? season,
    Value<int>? episode,
    Value<String?>? name,
    Value<String?>? still,
    Value<DateTime?>? airDate,
    Value<int>? rowid,
  }) {
    return EpisodesCompanion(
      showId: showId ?? this.showId,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      name: name ?? this.name,
      still: still ?? this.still,
      airDate: airDate ?? this.airDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (showId.present) {
      map['show_id'] = Variable<int>(showId.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (still.present) {
      map['still'] = Variable<String>(still.value);
    }
    if (airDate.present) {
      map['air_date'] = Variable<DateTime>(airDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('showId: $showId, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('name: $name, ')
          ..write('still: $still, ')
          ..write('airDate: $airDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchedEpisodesTable extends WatchedEpisodes
    with TableInfo<$WatchedEpisodesTable, WatchedEpisode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchedEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _showIdMeta = const VerificationMeta('showId');
  @override
  late final GeneratedColumn<int> showId = GeneratedColumn<int>(
    'show_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<int> season = GeneratedColumn<int>(
    'season',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeMeta = const VerificationMeta(
    'episode',
  );
  @override
  late final GeneratedColumn<int> episode = GeneratedColumn<int>(
    'episode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _watchedAtMeta = const VerificationMeta(
    'watchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> watchedAt = GeneratedColumn<DateTime>(
    'watched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [showId, season, episode, watchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watched_episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchedEpisode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('show_id')) {
      context.handle(
        _showIdMeta,
        showId.isAcceptableOrUnknown(data['show_id']!, _showIdMeta),
      );
    } else if (isInserting) {
      context.missing(_showIdMeta);
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    } else if (isInserting) {
      context.missing(_seasonMeta);
    }
    if (data.containsKey('episode')) {
      context.handle(
        _episodeMeta,
        episode.isAcceptableOrUnknown(data['episode']!, _episodeMeta),
      );
    } else if (isInserting) {
      context.missing(_episodeMeta);
    }
    if (data.containsKey('watched_at')) {
      context.handle(
        _watchedAtMeta,
        watchedAt.isAcceptableOrUnknown(data['watched_at']!, _watchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {showId, season, episode};
  @override
  WatchedEpisode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchedEpisode(
      showId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}show_id'],
      )!,
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season'],
      )!,
      episode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode'],
      )!,
      watchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}watched_at'],
      )!,
    );
  }

  @override
  $WatchedEpisodesTable createAlias(String alias) {
    return $WatchedEpisodesTable(attachedDatabase, alias);
  }
}

class WatchedEpisode extends DataClass implements Insertable<WatchedEpisode> {
  final int showId;
  final int season;
  final int episode;
  final DateTime watchedAt;
  const WatchedEpisode({
    required this.showId,
    required this.season,
    required this.episode,
    required this.watchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['show_id'] = Variable<int>(showId);
    map['season'] = Variable<int>(season);
    map['episode'] = Variable<int>(episode);
    map['watched_at'] = Variable<DateTime>(watchedAt);
    return map;
  }

  WatchedEpisodesCompanion toCompanion(bool nullToAbsent) {
    return WatchedEpisodesCompanion(
      showId: Value(showId),
      season: Value(season),
      episode: Value(episode),
      watchedAt: Value(watchedAt),
    );
  }

  factory WatchedEpisode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchedEpisode(
      showId: serializer.fromJson<int>(json['showId']),
      season: serializer.fromJson<int>(json['season']),
      episode: serializer.fromJson<int>(json['episode']),
      watchedAt: serializer.fromJson<DateTime>(json['watchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'showId': serializer.toJson<int>(showId),
      'season': serializer.toJson<int>(season),
      'episode': serializer.toJson<int>(episode),
      'watchedAt': serializer.toJson<DateTime>(watchedAt),
    };
  }

  WatchedEpisode copyWith({
    int? showId,
    int? season,
    int? episode,
    DateTime? watchedAt,
  }) => WatchedEpisode(
    showId: showId ?? this.showId,
    season: season ?? this.season,
    episode: episode ?? this.episode,
    watchedAt: watchedAt ?? this.watchedAt,
  );
  WatchedEpisode copyWithCompanion(WatchedEpisodesCompanion data) {
    return WatchedEpisode(
      showId: data.showId.present ? data.showId.value : this.showId,
      season: data.season.present ? data.season.value : this.season,
      episode: data.episode.present ? data.episode.value : this.episode,
      watchedAt: data.watchedAt.present ? data.watchedAt.value : this.watchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchedEpisode(')
          ..write('showId: $showId, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('watchedAt: $watchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(showId, season, episode, watchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchedEpisode &&
          other.showId == this.showId &&
          other.season == this.season &&
          other.episode == this.episode &&
          other.watchedAt == this.watchedAt);
}

class WatchedEpisodesCompanion extends UpdateCompanion<WatchedEpisode> {
  final Value<int> showId;
  final Value<int> season;
  final Value<int> episode;
  final Value<DateTime> watchedAt;
  final Value<int> rowid;
  const WatchedEpisodesCompanion({
    this.showId = const Value.absent(),
    this.season = const Value.absent(),
    this.episode = const Value.absent(),
    this.watchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchedEpisodesCompanion.insert({
    required int showId,
    required int season,
    required int episode,
    this.watchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : showId = Value(showId),
       season = Value(season),
       episode = Value(episode);
  static Insertable<WatchedEpisode> custom({
    Expression<int>? showId,
    Expression<int>? season,
    Expression<int>? episode,
    Expression<DateTime>? watchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (showId != null) 'show_id': showId,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
      if (watchedAt != null) 'watched_at': watchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchedEpisodesCompanion copyWith({
    Value<int>? showId,
    Value<int>? season,
    Value<int>? episode,
    Value<DateTime>? watchedAt,
    Value<int>? rowid,
  }) {
    return WatchedEpisodesCompanion(
      showId: showId ?? this.showId,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      watchedAt: watchedAt ?? this.watchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (showId.present) {
      map['show_id'] = Variable<int>(showId.value);
    }
    if (season.present) {
      map['season'] = Variable<int>(season.value);
    }
    if (episode.present) {
      map['episode'] = Variable<int>(episode.value);
    }
    if (watchedAt.present) {
      map['watched_at'] = Variable<DateTime>(watchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchedEpisodesCompanion(')
          ..write('showId: $showId, ')
          ..write('season: $season, ')
          ..write('episode: $episode, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MoviesTable extends Movies with TableInfo<$MoviesTable, Movie> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoviesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posterMeta = const VerificationMeta('poster');
  @override
  late final GeneratedColumn<String> poster = GeneratedColumn<String>(
    'poster',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runtimeMeta = const VerificationMeta(
    'runtime',
  );
  @override
  late final GeneratedColumn<int> runtime = GeneratedColumn<int>(
    'runtime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(110),
  );
  static const VerificationMeta _watchedAtMeta = const VerificationMeta(
    'watchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> watchedAt = GeneratedColumn<DateTime>(
    'watched_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    poster,
    runtime,
    watchedAt,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Movie> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('poster')) {
      context.handle(
        _posterMeta,
        poster.isAcceptableOrUnknown(data['poster']!, _posterMeta),
      );
    }
    if (data.containsKey('runtime')) {
      context.handle(
        _runtimeMeta,
        runtime.isAcceptableOrUnknown(data['runtime']!, _runtimeMeta),
      );
    }
    if (data.containsKey('watched_at')) {
      context.handle(
        _watchedAtMeta,
        watchedAt.isAcceptableOrUnknown(data['watched_at']!, _watchedAtMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Movie map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Movie(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      poster: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster'],
      ),
      runtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}runtime'],
      )!,
      watchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}watched_at'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $MoviesTable createAlias(String alias) {
    return $MoviesTable(attachedDatabase, alias);
  }
}

class Movie extends DataClass implements Insertable<Movie> {
  final int id;
  final String title;
  final String? poster;
  final int runtime;
  final DateTime? watchedAt;
  final DateTime addedAt;
  const Movie({
    required this.id,
    required this.title,
    this.poster,
    required this.runtime,
    this.watchedAt,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || poster != null) {
      map['poster'] = Variable<String>(poster);
    }
    map['runtime'] = Variable<int>(runtime);
    if (!nullToAbsent || watchedAt != null) {
      map['watched_at'] = Variable<DateTime>(watchedAt);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  MoviesCompanion toCompanion(bool nullToAbsent) {
    return MoviesCompanion(
      id: Value(id),
      title: Value(title),
      poster: poster == null && nullToAbsent
          ? const Value.absent()
          : Value(poster),
      runtime: Value(runtime),
      watchedAt: watchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(watchedAt),
      addedAt: Value(addedAt),
    );
  }

  factory Movie.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Movie(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      poster: serializer.fromJson<String?>(json['poster']),
      runtime: serializer.fromJson<int>(json['runtime']),
      watchedAt: serializer.fromJson<DateTime?>(json['watchedAt']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'poster': serializer.toJson<String?>(poster),
      'runtime': serializer.toJson<int>(runtime),
      'watchedAt': serializer.toJson<DateTime?>(watchedAt),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Movie copyWith({
    int? id,
    String? title,
    Value<String?> poster = const Value.absent(),
    int? runtime,
    Value<DateTime?> watchedAt = const Value.absent(),
    DateTime? addedAt,
  }) => Movie(
    id: id ?? this.id,
    title: title ?? this.title,
    poster: poster.present ? poster.value : this.poster,
    runtime: runtime ?? this.runtime,
    watchedAt: watchedAt.present ? watchedAt.value : this.watchedAt,
    addedAt: addedAt ?? this.addedAt,
  );
  Movie copyWithCompanion(MoviesCompanion data) {
    return Movie(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      poster: data.poster.present ? data.poster.value : this.poster,
      runtime: data.runtime.present ? data.runtime.value : this.runtime,
      watchedAt: data.watchedAt.present ? data.watchedAt.value : this.watchedAt,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Movie(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('poster: $poster, ')
          ..write('runtime: $runtime, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, poster, runtime, watchedAt, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Movie &&
          other.id == this.id &&
          other.title == this.title &&
          other.poster == this.poster &&
          other.runtime == this.runtime &&
          other.watchedAt == this.watchedAt &&
          other.addedAt == this.addedAt);
}

class MoviesCompanion extends UpdateCompanion<Movie> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> poster;
  final Value<int> runtime;
  final Value<DateTime?> watchedAt;
  final Value<DateTime> addedAt;
  const MoviesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.poster = const Value.absent(),
    this.runtime = const Value.absent(),
    this.watchedAt = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  MoviesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.poster = const Value.absent(),
    this.runtime = const Value.absent(),
    this.watchedAt = const Value.absent(),
    this.addedAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<Movie> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? poster,
    Expression<int>? runtime,
    Expression<DateTime>? watchedAt,
    Expression<DateTime>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (poster != null) 'poster': poster,
      if (runtime != null) 'runtime': runtime,
      if (watchedAt != null) 'watched_at': watchedAt,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  MoviesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String?>? poster,
    Value<int>? runtime,
    Value<DateTime?>? watchedAt,
    Value<DateTime>? addedAt,
  }) {
    return MoviesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      poster: poster ?? this.poster,
      runtime: runtime ?? this.runtime,
      watchedAt: watchedAt ?? this.watchedAt,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (poster.present) {
      map['poster'] = Variable<String>(poster.value);
    }
    if (runtime.present) {
      map['runtime'] = Variable<int>(runtime.value);
    }
    if (watchedAt.present) {
      map['watched_at'] = Variable<DateTime>(watchedAt.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoviesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('poster: $poster, ')
          ..write('runtime: $runtime, ')
          ..write('watchedAt: $watchedAt, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ShowsTable shows = $ShowsTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final $WatchedEpisodesTable watchedEpisodes = $WatchedEpisodesTable(
    this,
  );
  late final $MoviesTable movies = $MoviesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    shows,
    episodes,
    watchedEpisodes,
    movies,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'shows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('episodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'shows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('watched_episodes', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ShowsTableCreateCompanionBuilder =
    ShowsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> poster,
      Value<int?> totalEpisodes,
      Value<int?> seasonCount,
      Value<int> runtime,
      Value<String?> status,
      Value<DateTime> addedAt,
      Value<DateTime?> episodesSyncedAt,
    });
typedef $$ShowsTableUpdateCompanionBuilder =
    ShowsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> poster,
      Value<int?> totalEpisodes,
      Value<int?> seasonCount,
      Value<int> runtime,
      Value<String?> status,
      Value<DateTime> addedAt,
      Value<DateTime?> episodesSyncedAt,
    });

final class $$ShowsTableReferences
    extends BaseReferences<_$AppDatabase, $ShowsTable, Show> {
  $$ShowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EpisodesTable, List<Episode>> _episodesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.episodes,
    aliasName: 'shows__id__episodes__show_id',
  );

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.showId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WatchedEpisodesTable, List<WatchedEpisode>>
  _watchedEpisodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.watchedEpisodes,
    aliasName: 'shows__id__watched_episodes__show_id',
  );

  $$WatchedEpisodesTableProcessedTableManager get watchedEpisodesRefs {
    final manager = $$WatchedEpisodesTableTableManager(
      $_db,
      $_db.watchedEpisodes,
    ).filter((f) => f.showId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _watchedEpisodesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShowsTableFilterComposer extends Composer<_$AppDatabase, $ShowsTable> {
  $$ShowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get poster => $composableBuilder(
    column: $table.poster,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seasonCount => $composableBuilder(
    column: $table.seasonCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get episodesSyncedAt => $composableBuilder(
    column: $table.episodesSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> episodesRefs(
    Expression<bool> Function($$EpisodesTableFilterComposer f) f,
  ) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.showId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> watchedEpisodesRefs(
    Expression<bool> Function($$WatchedEpisodesTableFilterComposer f) f,
  ) {
    final $$WatchedEpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchedEpisodes,
      getReferencedColumn: (t) => t.showId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchedEpisodesTableFilterComposer(
            $db: $db,
            $table: $db.watchedEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShowsTable> {
  $$ShowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get poster => $composableBuilder(
    column: $table.poster,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seasonCount => $composableBuilder(
    column: $table.seasonCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get episodesSyncedAt => $composableBuilder(
    column: $table.episodesSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShowsTable> {
  $$ShowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get poster =>
      $composableBuilder(column: $table.poster, builder: (column) => column);

  GeneratedColumn<int> get totalEpisodes => $composableBuilder(
    column: $table.totalEpisodes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seasonCount => $composableBuilder(
    column: $table.seasonCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get runtime =>
      $composableBuilder(column: $table.runtime, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get episodesSyncedAt => $composableBuilder(
    column: $table.episodesSyncedAt,
    builder: (column) => column,
  );

  Expression<T> episodesRefs<T extends Object>(
    Expression<T> Function($$EpisodesTableAnnotationComposer a) f,
  ) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.showId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> watchedEpisodesRefs<T extends Object>(
    Expression<T> Function($$WatchedEpisodesTableAnnotationComposer a) f,
  ) {
    final $$WatchedEpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.watchedEpisodes,
      getReferencedColumn: (t) => t.showId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WatchedEpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.watchedEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShowsTable,
          Show,
          $$ShowsTableFilterComposer,
          $$ShowsTableOrderingComposer,
          $$ShowsTableAnnotationComposer,
          $$ShowsTableCreateCompanionBuilder,
          $$ShowsTableUpdateCompanionBuilder,
          (Show, $$ShowsTableReferences),
          Show,
          PrefetchHooks Function({bool episodesRefs, bool watchedEpisodesRefs})
        > {
  $$ShowsTableTableManager(_$AppDatabase db, $ShowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> poster = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<int?> seasonCount = const Value.absent(),
                Value<int> runtime = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> episodesSyncedAt = const Value.absent(),
              }) => ShowsCompanion(
                id: id,
                name: name,
                poster: poster,
                totalEpisodes: totalEpisodes,
                seasonCount: seasonCount,
                runtime: runtime,
                status: status,
                addedAt: addedAt,
                episodesSyncedAt: episodesSyncedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> poster = const Value.absent(),
                Value<int?> totalEpisodes = const Value.absent(),
                Value<int?> seasonCount = const Value.absent(),
                Value<int> runtime = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> episodesSyncedAt = const Value.absent(),
              }) => ShowsCompanion.insert(
                id: id,
                name: name,
                poster: poster,
                totalEpisodes: totalEpisodes,
                seasonCount: seasonCount,
                runtime: runtime,
                status: status,
                addedAt: addedAt,
                episodesSyncedAt: episodesSyncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ShowsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({episodesRefs = false, watchedEpisodesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (episodesRefs) db.episodes,
                    if (watchedEpisodesRefs) db.watchedEpisodes,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (episodesRefs)
                        await $_getPrefetchedData<Show, $ShowsTable, Episode>(
                          currentTable: table,
                          referencedTable: $$ShowsTableReferences
                              ._episodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShowsTableReferences(
                                db,
                                table,
                                p0,
                              ).episodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.showId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (watchedEpisodesRefs)
                        await $_getPrefetchedData<
                          Show,
                          $ShowsTable,
                          WatchedEpisode
                        >(
                          currentTable: table,
                          referencedTable: $$ShowsTableReferences
                              ._watchedEpisodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ShowsTableReferences(
                                db,
                                table,
                                p0,
                              ).watchedEpisodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.showId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ShowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShowsTable,
      Show,
      $$ShowsTableFilterComposer,
      $$ShowsTableOrderingComposer,
      $$ShowsTableAnnotationComposer,
      $$ShowsTableCreateCompanionBuilder,
      $$ShowsTableUpdateCompanionBuilder,
      (Show, $$ShowsTableReferences),
      Show,
      PrefetchHooks Function({bool episodesRefs, bool watchedEpisodesRefs})
    >;
typedef $$EpisodesTableCreateCompanionBuilder =
    EpisodesCompanion Function({
      required int showId,
      required int season,
      required int episode,
      Value<String?> name,
      Value<String?> still,
      Value<DateTime?> airDate,
      Value<int> rowid,
    });
typedef $$EpisodesTableUpdateCompanionBuilder =
    EpisodesCompanion Function({
      Value<int> showId,
      Value<int> season,
      Value<int> episode,
      Value<String?> name,
      Value<String?> still,
      Value<DateTime?> airDate,
      Value<int> rowid,
    });

final class $$EpisodesTableReferences
    extends BaseReferences<_$AppDatabase, $EpisodesTable, Episode> {
  $$EpisodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ShowsTable _showIdTable(_$AppDatabase db) =>
      db.shows.createAlias('episodes__show_id__shows__id');

  $$ShowsTableProcessedTableManager get showId {
    final $_column = $_itemColumn<int>('show_id')!;

    final manager = $$ShowsTableTableManager(
      $_db,
      $_db.shows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_showIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get still => $composableBuilder(
    column: $table.still,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnFilters(column),
  );

  $$ShowsTableFilterComposer get showId {
    final $$ShowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.shows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShowsTableFilterComposer(
            $db: $db,
            $table: $db.shows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get still => $composableBuilder(
    column: $table.still,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get airDate => $composableBuilder(
    column: $table.airDate,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShowsTableOrderingComposer get showId {
    final $$ShowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.shows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShowsTableOrderingComposer(
            $db: $db,
            $table: $db.shows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get still =>
      $composableBuilder(column: $table.still, builder: (column) => column);

  GeneratedColumn<DateTime> get airDate =>
      $composableBuilder(column: $table.airDate, builder: (column) => column);

  $$ShowsTableAnnotationComposer get showId {
    final $$ShowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.shows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShowsTableAnnotationComposer(
            $db: $db,
            $table: $db.shows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodesTable,
          Episode,
          $$EpisodesTableFilterComposer,
          $$EpisodesTableOrderingComposer,
          $$EpisodesTableAnnotationComposer,
          $$EpisodesTableCreateCompanionBuilder,
          $$EpisodesTableUpdateCompanionBuilder,
          (Episode, $$EpisodesTableReferences),
          Episode,
          PrefetchHooks Function({bool showId})
        > {
  $$EpisodesTableTableManager(_$AppDatabase db, $EpisodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> showId = const Value.absent(),
                Value<int> season = const Value.absent(),
                Value<int> episode = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> still = const Value.absent(),
                Value<DateTime?> airDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodesCompanion(
                showId: showId,
                season: season,
                episode: episode,
                name: name,
                still: still,
                airDate: airDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int showId,
                required int season,
                required int episode,
                Value<String?> name = const Value.absent(),
                Value<String?> still = const Value.absent(),
                Value<DateTime?> airDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodesCompanion.insert(
                showId: showId,
                season: season,
                episode: episode,
                name: name,
                still: still,
                airDate: airDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({showId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (showId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.showId,
                                referencedTable: $$EpisodesTableReferences
                                    ._showIdTable(db),
                                referencedColumn: $$EpisodesTableReferences
                                    ._showIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodesTable,
      Episode,
      $$EpisodesTableFilterComposer,
      $$EpisodesTableOrderingComposer,
      $$EpisodesTableAnnotationComposer,
      $$EpisodesTableCreateCompanionBuilder,
      $$EpisodesTableUpdateCompanionBuilder,
      (Episode, $$EpisodesTableReferences),
      Episode,
      PrefetchHooks Function({bool showId})
    >;
typedef $$WatchedEpisodesTableCreateCompanionBuilder =
    WatchedEpisodesCompanion Function({
      required int showId,
      required int season,
      required int episode,
      Value<DateTime> watchedAt,
      Value<int> rowid,
    });
typedef $$WatchedEpisodesTableUpdateCompanionBuilder =
    WatchedEpisodesCompanion Function({
      Value<int> showId,
      Value<int> season,
      Value<int> episode,
      Value<DateTime> watchedAt,
      Value<int> rowid,
    });

final class $$WatchedEpisodesTableReferences
    extends
        BaseReferences<_$AppDatabase, $WatchedEpisodesTable, WatchedEpisode> {
  $$WatchedEpisodesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShowsTable _showIdTable(_$AppDatabase db) =>
      db.shows.createAlias('watched_episodes__show_id__shows__id');

  $$ShowsTableProcessedTableManager get showId {
    final $_column = $_itemColumn<int>('show_id')!;

    final manager = $$ShowsTableTableManager(
      $_db,
      $_db.shows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_showIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WatchedEpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $WatchedEpisodesTable> {
  $$WatchedEpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get watchedAt => $composableBuilder(
    column: $table.watchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ShowsTableFilterComposer get showId {
    final $$ShowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.shows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShowsTableFilterComposer(
            $db: $db,
            $table: $db.shows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchedEpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $WatchedEpisodesTable> {
  $$WatchedEpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episode => $composableBuilder(
    column: $table.episode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get watchedAt => $composableBuilder(
    column: $table.watchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShowsTableOrderingComposer get showId {
    final $$ShowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.shows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShowsTableOrderingComposer(
            $db: $db,
            $table: $db.shows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchedEpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WatchedEpisodesTable> {
  $$WatchedEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get episode =>
      $composableBuilder(column: $table.episode, builder: (column) => column);

  GeneratedColumn<DateTime> get watchedAt =>
      $composableBuilder(column: $table.watchedAt, builder: (column) => column);

  $$ShowsTableAnnotationComposer get showId {
    final $$ShowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.shows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShowsTableAnnotationComposer(
            $db: $db,
            $table: $db.shows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WatchedEpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WatchedEpisodesTable,
          WatchedEpisode,
          $$WatchedEpisodesTableFilterComposer,
          $$WatchedEpisodesTableOrderingComposer,
          $$WatchedEpisodesTableAnnotationComposer,
          $$WatchedEpisodesTableCreateCompanionBuilder,
          $$WatchedEpisodesTableUpdateCompanionBuilder,
          (WatchedEpisode, $$WatchedEpisodesTableReferences),
          WatchedEpisode,
          PrefetchHooks Function({bool showId})
        > {
  $$WatchedEpisodesTableTableManager(
    _$AppDatabase db,
    $WatchedEpisodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchedEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchedEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchedEpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> showId = const Value.absent(),
                Value<int> season = const Value.absent(),
                Value<int> episode = const Value.absent(),
                Value<DateTime> watchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchedEpisodesCompanion(
                showId: showId,
                season: season,
                episode: episode,
                watchedAt: watchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int showId,
                required int season,
                required int episode,
                Value<DateTime> watchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchedEpisodesCompanion.insert(
                showId: showId,
                season: season,
                episode: episode,
                watchedAt: watchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WatchedEpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({showId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (showId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.showId,
                                referencedTable:
                                    $$WatchedEpisodesTableReferences
                                        ._showIdTable(db),
                                referencedColumn:
                                    $$WatchedEpisodesTableReferences
                                        ._showIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WatchedEpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WatchedEpisodesTable,
      WatchedEpisode,
      $$WatchedEpisodesTableFilterComposer,
      $$WatchedEpisodesTableOrderingComposer,
      $$WatchedEpisodesTableAnnotationComposer,
      $$WatchedEpisodesTableCreateCompanionBuilder,
      $$WatchedEpisodesTableUpdateCompanionBuilder,
      (WatchedEpisode, $$WatchedEpisodesTableReferences),
      WatchedEpisode,
      PrefetchHooks Function({bool showId})
    >;
typedef $$MoviesTableCreateCompanionBuilder =
    MoviesCompanion Function({
      Value<int> id,
      required String title,
      Value<String?> poster,
      Value<int> runtime,
      Value<DateTime?> watchedAt,
      Value<DateTime> addedAt,
    });
typedef $$MoviesTableUpdateCompanionBuilder =
    MoviesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String?> poster,
      Value<int> runtime,
      Value<DateTime?> watchedAt,
      Value<DateTime> addedAt,
    });

class $$MoviesTableFilterComposer
    extends Composer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get poster => $composableBuilder(
    column: $table.poster,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get watchedAt => $composableBuilder(
    column: $table.watchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MoviesTableOrderingComposer
    extends Composer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get poster => $composableBuilder(
    column: $table.poster,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get watchedAt => $composableBuilder(
    column: $table.watchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MoviesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MoviesTable> {
  $$MoviesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get poster =>
      $composableBuilder(column: $table.poster, builder: (column) => column);

  GeneratedColumn<int> get runtime =>
      $composableBuilder(column: $table.runtime, builder: (column) => column);

  GeneratedColumn<DateTime> get watchedAt =>
      $composableBuilder(column: $table.watchedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$MoviesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MoviesTable,
          Movie,
          $$MoviesTableFilterComposer,
          $$MoviesTableOrderingComposer,
          $$MoviesTableAnnotationComposer,
          $$MoviesTableCreateCompanionBuilder,
          $$MoviesTableUpdateCompanionBuilder,
          (Movie, BaseReferences<_$AppDatabase, $MoviesTable, Movie>),
          Movie,
          PrefetchHooks Function()
        > {
  $$MoviesTableTableManager(_$AppDatabase db, $MoviesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoviesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoviesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoviesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> poster = const Value.absent(),
                Value<int> runtime = const Value.absent(),
                Value<DateTime?> watchedAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => MoviesCompanion(
                id: id,
                title: title,
                poster: poster,
                runtime: runtime,
                watchedAt: watchedAt,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String?> poster = const Value.absent(),
                Value<int> runtime = const Value.absent(),
                Value<DateTime?> watchedAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
              }) => MoviesCompanion.insert(
                id: id,
                title: title,
                poster: poster,
                runtime: runtime,
                watchedAt: watchedAt,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MoviesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MoviesTable,
      Movie,
      $$MoviesTableFilterComposer,
      $$MoviesTableOrderingComposer,
      $$MoviesTableAnnotationComposer,
      $$MoviesTableCreateCompanionBuilder,
      $$MoviesTableUpdateCompanionBuilder,
      (Movie, BaseReferences<_$AppDatabase, $MoviesTable, Movie>),
      Movie,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ShowsTableTableManager get shows =>
      $$ShowsTableTableManager(_db, _db.shows);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$WatchedEpisodesTableTableManager get watchedEpisodes =>
      $$WatchedEpisodesTableTableManager(_db, _db.watchedEpisodes);
  $$MoviesTableTableManager get movies =>
      $$MoviesTableTableManager(_db, _db.movies);
}
