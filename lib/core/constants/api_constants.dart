class KugouApi {
  static const base = 'http://mobilecdn.kugou.com';
  static const lyricsBase = 'http://lyrics.kugou.com';
  static const lyricsSearch = 'http://krcs.kugou.com/search';
  static const lyricsDownload = 'http://lyrics.kugou.com/download';

  static String searchSongs(String keyword, {int page = 1, int pageSize = 20}) =>
      '$base/api/v3/search/song?format=json&keyword=$keyword&page=$page&pagesize=$pageSize';

  static String playlistSongs(String specialId, {int page = 1, int pageSize = 100}) =>
      '$base/api/v3/song/list?specialid=$specialId&page=$page&pagesize=$pageSize';
}
