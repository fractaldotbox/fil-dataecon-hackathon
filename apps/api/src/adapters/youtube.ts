export const asYoutubeUrl = (videoId: string) => {
  return 'https://www.youtube.com/watch?v=' + videoId;
};

export const asKey = (videoId: string) => 'youtube-' + videoId;
