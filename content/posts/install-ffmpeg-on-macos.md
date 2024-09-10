+++
title = 'Install Ffmpeg on Macos'
date = 2020-03-01T23:12:07+08:00
draft = false
pin = true
summary = 'FFmpeg is a free and open-source project consisting of a vast software suite of libraries and programs for handling video, audio, and other multimedia files and streams.'
+++

![image](https://images.unsplash.com/photo-1565221287653-9a2713dbe4ef?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ)

> FFmpeg is a free and open-source project consisting of a vast software suite of libraries and programs for handling video, audio, and other multimedia files and streams. (Wikipeida)
> 

## Before install

first of all you need install brew, copy and paste the following command to your terminal

```bash
/usr/bin/ruby -e "$(curl -fsSL <https://raw.githubusercontent.com/Homebrew/install/master/install>)"
```

## Install FFmpeg

you can't directly run `brew install ffmpeg` yet, base on [official documentation](https://trac.ffmpeg.org/wiki/CompilationGuide/macOS).

> Since v2.0, Homebrew does not offer options for its core formulae anymore. Users who want to build ffmpeg with additional libraries (including non-free ones) need to use so-called taps from third party repositories. These repositories are not maintained by Homebrew.
> 

for example, you need both x264 and x256(HEVC) encoder support. (what is the difference between H.264 & H.265, what is NVENC from Nvidia? I will write a blog special for it.)

you have to tap third party brew repository, step by step, you will get there.

1. add third party tap to brew
    
    ```bash
    brew tap homebrew-ffmpeg/ffmpeg
    ```
    
2. check options
    
    ```bash
    brew options homebrew-ffmpeg/ffmpeg/ffmpeg
    ```
    
3. install every options (if never know which codec you gonna to using)
    
    ```bash
    brew install homebrew-ffmpeg/ffmpeg/ffmpeg $(brew options homebrew-ffmpeg/ffmpeg/ffmpeg | grep -vE '\\s' | grep -- '--with-' | tr '\\n' ' ')
    ```
    

## Test FFmpeg

please download [sample H.264](http://demo.nimius.net/video_test/videos/test.mp4) , and navigate to that file located folder, and run

```bash
ffmpeg -i test.mp4 -c:v libx265 -c:a copy x265.mp4
```

you'll get x265.mp4 at the same folder.

let me explain a bit for this command,

- i : input file
- c:v : covert video, libx256 is the video codec we're using here, default present option for libx256 is medium
- c:a : covert audio, copy means use copy the audio in it's original codec, if we put nothing for audio, by default it will convert original audio to acc via acc codec (what's the difference between acc and mp3, I will talk about this in another blog post)

if you're interested on more FFmpeg common scripts and explanation, please waiting for me next blog post.

Cheers and Stay hungry.