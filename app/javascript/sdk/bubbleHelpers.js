import { addClasses, removeClasses, toggleClass } from './DOMHelpers';
import { IFrameHelper } from './IFrameHelper';
import { isExpandedView } from './settingsHelper';
import {
  CHATWOOT_CLOSED,
  CHATWOOT_OPENED,
} from '../widget/constants/sdkEvents';
import { dispatchWindowEvent } from 'shared/helpers/CustomEventHelper';

export const bubbleSVG = [
  'M418.643,21.318H221.353c-51.547,0-93.355,41.807-93.355,93.355v13.312H93.355C41.807,127.984,0,169.792,0,221.339v88.683c0,55.289,26.377,95.296,76.864,95.296h8.469v64c0,22.932,31.239,29.714,40.747,8.845c7.211-15.827,19.353-30.833,35.143-44.611c9.913-8.65,20.621-16.265,31.321-22.725c3.835-2.315,7.11-4.157,9.649-5.509h75.14c52.857,0,106.667-44.46,106.667-95.296v-11.371h51.134c50.487,0,76.864-40.007,76.864-95.296v-88.683C511.998,63.119,470.206,21.318,418.643,21.318z M277.333,362.651H197.12c-3.133,0-6.227,0.69-9.063,2.021c-3.758,1.764-9.867,4.982-17.563,9.628c-12.7,7.667-25.394,16.695-37.322,27.103c-1.756,1.533-3.481,3.081-5.172,4.647v-22.065c0-11.782-9.551-21.333-21.333-21.333H76.864c-22.276,0-34.197-18.081-34.197-52.629v-88.683c0-27.983,22.705-50.688,50.688-50.688h55.977h141.312c1.198,0,2.383,0.057,3.56,0.138c21.165,1.471,38.766,15.936,44.849,35.478c1.481,4.761,2.279,9.823,2.279,15.072v55.979c0,0.015,0.002,0.029,0.002,0.044v32.661C341.333,335.302,308.233,362.651,277.333,362.651z M469.331,203.355c0,34.548-11.921,52.629-34.197,52.629H384v-34.645c0-9.74-1.495-19.131-4.264-27.959c-11.505-36.697-45.057-63.637-85.143-65.306c-1.31-0.055-2.625-0.089-3.948-0.089h-0.002H170.665v-13.312c0-27.983,22.705-50.688,50.688-50.688h197.291c27.996,0,50.688,22.696,50.688,50.688V203.355z',
  'M192,234.651c-11.776,0-21.333,9.557-21.333,21.333c0,11.776,9.557,21.333,21.333,21.333s21.333-9.557,21.333-21.333C213.333,244.208,203.776,234.651,192,234.651z',
  'M277.333,234.651c-11.776,0-21.333,9.557-21.333,21.333c0,11.776,9.557,21.333,21.333,21.333s21.333-9.557,21.333-21.333C298.667,244.208,289.109,234.651,277.333,234.651z',
  'M106.667,234.651c-11.776,0-21.333,9.557-21.333,21.333c0,11.776,9.557,21.333,21.333,21.333S128,267.76,128,255.984C128,244.208,118.443,234.651,106.667,234.651z',
];

export const body = document.getElementsByTagName('body')[0];
export const widgetHolder = document.createElement('div');

export const bubbleHolder = document.createElement('div');
export const chatBubble = document.createElement('button');
export const closeBubble = document.createElement('button');
export const notificationBubble = document.createElement('span');

export const setBubbleText = bubbleText => {
  if (isExpandedView(window.$chatwoot.type)) {
    const textNode = document.getElementById('woot-widget--expanded__text');
    textNode.innerText = bubbleText;
  }
};

export const createBubbleIcon = ({ className, path, target }) => {
  let bubbleClassName = `${className} woot-elements--${window.$chatwoot.position}`;
  const bubbleIcon = document.createElementNS(
    'http://www.w3.org/2000/svg',
    'svg'
  );
  bubbleIcon.setAttributeNS(null, 'id', 'woot-widget-bubble-icon');
  bubbleIcon.setAttributeNS(null, 'width', '24');
  bubbleIcon.setAttributeNS(null, 'height', '24');
  bubbleIcon.setAttributeNS(
    null,
    'viewBox',
    Array.isArray(path) ? '0 0 511.998 511.998' : '0 0 240 240'
  );
  bubbleIcon.setAttributeNS(null, 'fill', 'none');
  bubbleIcon.setAttribute('xmlns', 'http://www.w3.org/2000/svg');

  if (Array.isArray(path)) {
    path.forEach(d => {
      const bubblePath = document.createElementNS(
        'http://www.w3.org/2000/svg',
        'path'
      );
      bubblePath.setAttributeNS(null, 'd', d);
      bubblePath.setAttributeNS(null, 'fill', '#FFFFFF');
      bubbleIcon.appendChild(bubblePath);
    });
  } else {
    const bubblePath = document.createElementNS(
      'http://www.w3.org/2000/svg',
      'path'
    );
    bubblePath.setAttributeNS(null, 'd', path);
    bubblePath.setAttributeNS(null, 'fill', '#FFFFFF');
    bubbleIcon.appendChild(bubblePath);
  }
  target.appendChild(bubbleIcon);

  if (isExpandedView(window.$chatwoot.type)) {
    const textNode = document.createElement('div');
    textNode.id = 'woot-widget--expanded__text';
    textNode.innerText = '';
    target.appendChild(textNode);
    bubbleClassName += ' woot-widget--expanded';
  }

  target.className = bubbleClassName;
  target.title = 'Open chat window';
  return target;
};

export const createBubbleHolder = hideMessageBubble => {
  if (hideMessageBubble) {
    addClasses(bubbleHolder, 'woot-hidden');
  }
  addClasses(bubbleHolder, 'woot--bubble-holder');
  bubbleHolder.id = 'cw-bubble-holder';
  bubbleHolder.dataset.turboPermanent = true;
  body.appendChild(bubbleHolder);
};

const handleBubbleToggle = newIsOpen => {
  IFrameHelper.events.onBubbleToggle(newIsOpen);

  if (newIsOpen) {
    dispatchWindowEvent({ eventName: CHATWOOT_OPENED });
  } else {
    dispatchWindowEvent({ eventName: CHATWOOT_CLOSED });
    chatBubble.focus();
  }
};

export const onBubbleClick = (props = {}) => {
  const { toggleValue } = props;
  const { isOpen } = window.$chatwoot;
  if (isOpen === toggleValue) return;

  const newIsOpen = toggleValue === undefined ? !isOpen : toggleValue;
  window.$chatwoot.isOpen = newIsOpen;

  toggleClass(chatBubble, 'woot--hide');
  toggleClass(closeBubble, 'woot--hide');
  toggleClass(widgetHolder, 'woot--hide');

  handleBubbleToggle(newIsOpen);
};

export const onClickChatBubble = () => {
  bubbleHolder.addEventListener('click', onBubbleClick);
};

export const addUnreadClass = () => {
  const holderEl = document.querySelector('.woot-widget-holder');
  addClasses(holderEl, 'has-unread-view');
};

export const removeUnreadClass = () => {
  const holderEl = document.querySelector('.woot-widget-holder');
  removeClasses(holderEl, 'has-unread-view');
};
